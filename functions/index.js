const { onCall, HttpsError } = require("firebase-functions/v2/https");
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
