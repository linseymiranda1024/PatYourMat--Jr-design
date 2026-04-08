const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { initializeApp } = require("firebase-admin/app");

// Initialize Firebase Admin SDK
initializeApp();
const db = getFirestore();

/**
 * HTTPS Callable Function to register a user for a class.
 * 
 * Requirements:
 * - User must be authenticated.
 * - Class must exist in 'classes/{classId}'.
 * - Class must have capacity (registeredCount < capacity).
 * - User must not already be registered for the class.
 * - Uses a Firestore transaction for atomicity.
 */
exports.registerForClass = onCall(async (request) => {
  // 1. Verify User Authentication
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const uid = auth.uid;
  const { classId } = request.data;

  // Validate Input
  if (!classId || typeof classId !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "The function must be called with a valid 'classId'."
    );
  }

  try {
    return await db.runTransaction(async (transaction) => {
      const classRef = db.collection("classes").doc(classId);
      const userRegistrationRef = db
        .collection("users")
        .doc(uid)
        .collection("registrations")
        .doc(classId);
      const classRegistrationRef = db
        .collection("classes")
        .doc(classId)
        .collection("registrations")
        .doc(uid);

      // 2. Check if the class exists
      const classDoc = await transaction.get(classRef);
      if (!classDoc.exists) {
        throw new HttpsError("not-found", "The specified class does not exist.");
      }

      const classData = classDoc.data();
      const capacity = classData.capacity || 0;
      const registeredCount = classData.registeredCount || 0;

      // 3. Check that registeredCount < capacity
      if (registeredCount >= capacity) {
        throw new HttpsError("failed-precondition", "The class is already at full capacity.");
      }

      // 4. Prevent duplicate registration
      const registrationDoc = await transaction.get(userRegistrationRef);
      if (registrationDoc.exists) {
        throw new HttpsError("already-exists", "The user is already registered for this class.");
      }

      // 5. Perform the updates
      // - Create user registration document
      transaction.set(userRegistrationRef, {
        classId: classId,
        timestamp: FieldValue.serverTimestamp(),
      });

      // - Create class registration document
      transaction.set(classRegistrationRef, {
        uid: uid,
        timestamp: FieldValue.serverTimestamp(),
      });

      // - Increment registeredCount in class document
      transaction.update(classRef, {
        registeredCount: FieldValue.increment(1),
      });

      return { success: true, message: "Successfully registered for the class." };
    });
  } catch (error) {
    // If it's already an HttpsError, rethrow it
    if (error instanceof HttpsError) {
      throw error;
    }
    
    // Log unexpected errors for debugging
    console.error("Registration Transaction Error:", error);
    
    // Throw a generic internal error to the client
    throw new HttpsError("internal", "An error occurred while processing the registration.");
  }
});

/**
 * Firestore Trigger Function to promote users from standby queue when a spot opens up.
 * 
 * Trigger: onDelete of a document in classes/{classId}/registrations/{userId}
 * 
 * Logic:
 * 1. Check if the standby_queue for this classId has any documents.
 * 2. If yes, retrieve the oldest document (ordered by createdAt).
 * 3. Start a Firestore Transaction:
 *    - Verify the class still has an open spot (capacity > filled).
 *    - Find an available mat number (by checking the reservedMats array in the class document).
 *    - Create the registration documents:
 *      - user_profiles/{userId}/registrations/{classId}
 *      - classes/{classId}/registrations/{userId}
 *    - Update the class document:
 *      - Increment filled and registeredCount.
 *      - Add the user to the roster map.
 *      - Add the assigned mat to the reservedMats array.
 *    - Delete the user's document from classes/{classId}/standby_queue.
 */
exports.promoteFromStandbyQueue = onDocumentDeleted(
  "classes/{classId}/registrations/{userId}",
  async (event) => {
    const classId = event.params.classId;
    const cancelledUserId = event.params.userId;

    try {
      await db.runTransaction(async (transaction) => {
        // Get the class document
        const classRef = db.collection("classes").doc(classId);
        const classDoc = await transaction.get(classRef);
        if (!classDoc.exists) {
          return; // Class no longer exists
        }

        const classData = classDoc.data();
        const capacity = classData.capacity || 0;
        const filled = classData.filled || 0;
        const reservedMats = classData.reservedMats || [];

        // Check if there's an open spot
        if (filled >= capacity) {
          return; // No open spot
        }

        // Get the standby queue, ordered by createdAt
        const standbyRef = db.collection("classes").doc(classId).collection("standby_queue");
        const standbyQuery = standbyRef.orderBy("createdAt", "asc").limit(1);
        const standbySnapshot = await transaction.get(standbyQuery);

        if (standbySnapshot.empty) {
          return; // No one in standby
        }

        const standbyDoc = standbySnapshot.docs[0];
        const standbyData = standbyDoc.data();
        const userId = standbyDoc.id; // userId is the document ID
        const userName = standbyData.userName;
        const userEmail = standbyData.userEmail;

        // Find an available mat
        const availableMats = [];
        for (let i = 1; i <= capacity; i++) {
          const matString = `Mat #${i}`;
          if (!reservedMats.includes(matString)) {
            availableMats.push(matString);
          }
        }

        if (availableMats.length === 0) {
          return; // No available mats
        }

        // Pick the first available mat
        const assignedMat = availableMats[0];

        // Build registration data
        const registrationData = {
          userId: userId,
          userName: userName,
          userEmail: userEmail,
          classId: classId,
          className: classData.title || '',
          instructor: classData.instructor || '',
          dateTime: `${classData.dateText || ''} at ${classData.timeText || ''}`,
          date: classData.dateTime,
          type: classData.type || '',
          matNumber: assignedMat,
          status: 'confirmed',
          createdAt: FieldValue.serverTimestamp(),
        };

        // Build roster data
        const rosterData = {
          userId: userId,
          userName: userName,
          userEmail: userEmail,
          matNumber: assignedMat,
          status: 'confirmed',
          createdAt: FieldValue.serverTimestamp(),
        };

        // Create registration documents
        const userRegistrationRef = db.collection("user_profiles").doc(userId).collection("registrations").doc(classId);
        const classRegistrationRef = db.collection("classes").doc(classId).collection("registrations").doc(userId);

        transaction.set(userRegistrationRef, registrationData);
        transaction.set(classRegistrationRef, registrationData);

        // Update class document
        const newFilled = filled + 1;
        const rosterField = `roster.${userId}`;
        transaction.update(classRef, {
          filled: newFilled,
          registeredCount: newFilled,
          status: newFilled >= capacity ? 'full' : 'open',
          reservedMats: FieldValue.arrayUnion([assignedMat]),
          [rosterField]: rosterData,
          standbyCount: FieldValue.increment(-1),
        });

        // Delete from standby queue
        transaction.delete(standbyDoc.ref);

        console.log(`Promoted user ${userId} from standby to registered for class ${classId} with mat ${assignedMat}`);
      });
    } catch (error) {
      console.error("Error promoting from standby queue:", error);
    }
  }
);
