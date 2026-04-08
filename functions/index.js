const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { initializeApp } = require("firebase-admin/app");

// Initialize Firebase Admin SDK
initializeApp();
const db = getFirestore();

function toInt(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  return 0;
}

function formatClassDateTime(rawDateTime) {
  const date = rawDateTime?.toDate?.() ?? null;
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
    return "";
  }

  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  const weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const hours24 = date.getHours();
  const hours12 = hours24 % 12 === 0 ? 12 : hours24 % 12;
  const minutes = String(date.getMinutes()).padStart(2, "0");
  const amPm = hours24 >= 12 ? "PM" : "AM";

  return `${weekdays[date.getDay()]}, ${months[date.getMonth()]} ${date.getDate()} at ${hours12}:${minutes} ${amPm}`;
}

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

    try {
      await db.runTransaction(async (transaction) => {
        const classRef = db.collection("classes").doc(classId);
        const classDoc = await transaction.get(classRef);
        if (!classDoc.exists) {
          return;
        }

        const classData = classDoc.data();
        const capacity = toInt(classData.capacity);
        const reservedMats = Array.isArray(classData.reservedMats) ?
          classData.reservedMats.filter((value) => typeof value === "string" && value.trim()) :
          [];
        const occupiedCount = reservedMats.length;
        const currentStandbyCount = toInt(classData.standbyCount);

        if (capacity <= 0 || occupiedCount >= capacity) {
          return;
        }

        const standbyRef = db.collection("classes").doc(classId).collection("standby_queue");
        const standbyQuery = standbyRef.orderBy("createdAt", "asc").limit(1);
        const standbySnapshot = await transaction.get(standbyQuery);

        if (standbySnapshot.empty) {
          return;
        }

        const standbyDoc = standbySnapshot.docs[0];
        const standbyData = standbyDoc.data();
        const userId = standbyDoc.id;
        const userName = standbyData.userName || "";
        const userEmail = standbyData.userEmail || "";

        const availableMats = [];
        for (let i = 1; i <= capacity; i++) {
          const matString = `Mat #${i}`;
          if (!reservedMats.includes(matString)) {
            availableMats.push(matString);
          }
        }

        if (availableMats.length === 0) {
          return;
        }

        const assignedMat = availableMats[0];
        const formattedDateTime = formatClassDateTime(classData.dateTime);

        const registrationData = {
          userId: userId,
          userName: userName,
          userEmail: userEmail,
          classId: classId,
          className: classData.title || "",
          instructor: classData.instructor || "",
          dateTime: formattedDateTime,
          date: classData.dateTime,
          type: classData.type || "",
          matNumber: assignedMat,
          status: "CONFIRMED",
          createdAt: FieldValue.serverTimestamp(),
        };

        const rosterData = {
          userId: userId,
          userName: userName,
          userEmail: userEmail,
          matNumber: assignedMat,
          status: "CONFIRMED",
          createdAt: FieldValue.serverTimestamp(),
        };

        const userRegistrationRef = db.collection("user_profiles").doc(userId).collection("registrations").doc(classId);
        const classRegistrationRef = db.collection("classes").doc(classId).collection("registrations").doc(userId);
        const notificationRef = db.collection("user_profiles")
          .doc(userId)
          .collection("notifications")
          .doc(`standby-promotion-${classId}`);

        transaction.set(userRegistrationRef, registrationData);
        transaction.set(classRegistrationRef, registrationData);
        transaction.set(notificationRef, {
          title: "Spot opened up",
          message: `You were moved off standby and into ${classData.title || "your class"}. Your mat is ${assignedMat}.`,
          type: "standby_promoted",
          is_read: false,
          class_id: classId,
          created_at: FieldValue.serverTimestamp(),
        }, {merge: true});

        const newFilled = occupiedCount + 1;
        const rosterField = `roster.${userId}`;
        transaction.update(classRef, {
          filled: newFilled,
          registeredCount: newFilled,
          status: newFilled >= capacity ? "full" : "open",
          reservedMats: FieldValue.arrayUnion(assignedMat),
          [rosterField]: rosterData,
          standbyCount: Math.max(0, currentStandbyCount - 1),
        });

        transaction.delete(standbyDoc.ref);

        console.log(`Promoted user ${userId} from standby to registered for class ${classId} with mat ${assignedMat}`);
      });
    } catch (error) {
      console.error("Error promoting from standby queue:", error);
    }
  }
);
