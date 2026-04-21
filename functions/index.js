const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentDeleted} = require("firebase-functions/v2/firestore");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {initializeApp} = require("firebase-admin/app");

initializeApp();
const db = getFirestore();

function toInt(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  return 0;
}

function toTrimmedString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function buildUserName(userProfileData) {
  const firstName = toTrimmedString(userProfileData.first_name);
  const lastName = toTrimmedString(userProfileData.last_name);
  const fullName = [firstName, lastName].filter(Boolean).join(" ").trim();
  if (fullName) {
    return fullName;
  }

  const email = toTrimmedString(userProfileData.email);
  return email || "Member";
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

function parseReservedMats(rawValue) {
  const reservedMats = new Set();
  if (!Array.isArray(rawValue)) {
    return reservedMats;
  }

  for (const value of rawValue) {
    const trimmedValue = toTrimmedString(value);
    if (trimmedValue) {
      reservedMats.add(trimmedValue);
    }
  }
  return reservedMats;
}

function parseMatNumber(rawValue) {
  const match = /(\d+)/.exec(toTrimmedString(rawValue));
  return match ? Number.parseInt(match[1], 10) : null;
}

function sortReservedMats(reservedMats) {
  return [...reservedMats].sort((left, right) => {
    const leftValue = parseMatNumber(left) ?? Number.MAX_SAFE_INTEGER;
    const rightValue = parseMatNumber(right) ?? Number.MAX_SAFE_INTEGER;
    return leftValue - rightValue;
  });
}

function pickAvailableMat(capacity, reservedMats) {
  for (let matNumber = 1; matNumber <= capacity; matNumber += 1) {
    const matLabel = `Mat #${matNumber}`;
    if (!reservedMats.has(matLabel)) {
      return matLabel;
    }
  }
  return null;
}

function resolveClassType(classData) {
  return toTrimmedString(classData.type) || toTrimmedString(classData.category);
}

function resolveClassStatus({filled, capacity, standbyCount}) {
  return filled < capacity && toInt(standbyCount) === 0 ? "open" : "full";
}

function buildRegistrationData({
  userId,
  userName,
  userEmail,
  classId,
  classData,
  matNumber,
}) {
  const registrationData = {
    userId,
    userName,
    userEmail,
    classId,
    className: toTrimmedString(classData.title),
    instructor: toTrimmedString(classData.instructor),
    dateTime: formatClassDateTime(classData.dateTime),
    matNumber,
    status: "CONFIRMED",
    createdAt: FieldValue.serverTimestamp(),
  };

  if (classData.dateTime != null) {
    registrationData.date = classData.dateTime;
  }

  const classType = resolveClassType(classData);
  if (classType) {
    registrationData.type = classType;
  }

  const durationMinutes = toInt(classData.durationMinutes);
  if (durationMinutes > 0) {
    registrationData.durationMinutes = durationMinutes;
  }

  const location = toTrimmedString(classData.location);
  if (location) {
    registrationData.location = location;
  }

  return registrationData;
}

function buildRosterData({userId, userName, userEmail, matNumber}) {
  return {
    userId,
    userName,
    userEmail,
    matNumber,
    status: "CONFIRMED",
    createdAt: FieldValue.serverTimestamp(),
  };
}

function buildClassMetadataUpdate({
  reservedMats,
  capacity,
  standbyCount,
  extraFields = {},
}) {
  const filled = Math.min(reservedMats.size, Math.max(0, capacity));
  return {
    filled,
    registeredCount: filled,
    standbyCount: Math.max(0, toInt(standbyCount)),
    status: resolveClassStatus({filled, capacity, standbyCount}),
    reservedMats: sortReservedMats(reservedMats),
    ...extraFields,
  };
}

function chunkArray(values, chunkSize) {
  const chunks = [];
  for (let index = 0; index < values.length; index += chunkSize) {
    chunks.push(values.slice(index, index + chunkSize));
  }
  return chunks;
}

async function deleteDocumentRefsInBatches(documentRefs) {
  const refsToDelete = documentRefs.filter(Boolean);
  for (const refsChunk of chunkArray(refsToDelete, 450)) {
    const batch = db.batch();
    for (const ref of refsChunk) {
      batch.delete(ref);
    }
    await batch.commit();
  }
}

function addUniqueDocumentRef(refsByPath, ref) {
  if (ref?.path) {
    refsByPath.set(ref.path, ref);
  }
}

async function collectDocumentDescendantRefs(docRef, refsByPath) {
  const subcollections = await docRef.listCollections();
  for (const subcollection of subcollections) {
    const snapshot = await subcollection.get();
    for (const doc of snapshot.docs) {
      await collectDocumentDescendantRefs(doc.ref, refsByPath);
      addUniqueDocumentRef(refsByPath, doc.ref);
    }
  }
}

async function collectClassRelatedDeleteRefs(classId) {
  const refsByPath = new Map();
  const classRef = db.collection("classes").doc(classId);

  await collectDocumentDescendantRefs(classRef, refsByPath);

  const userProfilesSnapshot = await db.collection("user_profiles").get();
  await Promise.all(userProfilesSnapshot.docs.map(async (userDoc) => {
    const registrationsRef = userDoc.ref.collection("registrations");
    const notificationsRef = userDoc.ref.collection("notifications");

    const [
      registrationByIdDoc,
      registrationByClassIdSnapshot,
      notificationsBySnakeCaseSnapshot,
      notificationsByCamelCaseSnapshot,
    ] = await Promise.all([
      registrationsRef.doc(classId).get(),
      registrationsRef.where("classId", "==", classId).get(),
      notificationsRef.where("class_id", "==", classId).get(),
      notificationsRef.where("classId", "==", classId).get(),
    ]);

    if (registrationByIdDoc.exists) {
      addUniqueDocumentRef(refsByPath, registrationByIdDoc.ref);
    }
    for (const doc of registrationByClassIdSnapshot.docs) {
      addUniqueDocumentRef(refsByPath, doc.ref);
    }
    for (const doc of notificationsBySnakeCaseSnapshot.docs) {
      addUniqueDocumentRef(refsByPath, doc.ref);
    }
    for (const doc of notificationsByCamelCaseSnapshot.docs) {
      addUniqueDocumentRef(refsByPath, doc.ref);
    }
  }));

  return {
    classRef,
    relatedRefs: [...refsByPath.values()],
  };
}

async function assertStaffUser(uid) {
  const profileDoc = await db.collection("user_profiles").doc(uid).get();
  if (!profileDoc.exists || profileDoc.data()?.role !== "Staff") {
    throw new HttpsError(
        "permission-denied",
        "Only staff members can delete classes.",
    );
  }
}

exports.registerForClass = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError(
        "unauthenticated",
        "The function must be called while authenticated.",
    );
  }

  const uid = auth.uid;
  const classId = toTrimmedString(request.data?.classId);
  if (!classId) {
    throw new HttpsError(
        "invalid-argument",
        "The function must be called with a valid 'classId'.",
    );
  }

  try {
    return await db.runTransaction(async (transaction) => {
      const classRef = db.collection("classes").doc(classId);
      const userProfileRef = db.collection("user_profiles").doc(uid);
      const userRegistrationRef = userProfileRef
          .collection("registrations")
          .doc(classId);
      const classRegistrationRef = classRef
          .collection("registrations")
          .doc(uid);
      const userStandbyRef = classRef.collection("standby_queue").doc(uid);
      const standbyQuery = classRef
          .collection("standby_queue")
          .orderBy("createdAt", "asc");

      const classDoc = await transaction.get(classRef);
      if (!classDoc.exists) {
        throw new HttpsError("not-found", "The specified class does not exist.");
      }

      const classData = classDoc.data() || {};
      const capacity = toInt(classData.capacity);
      const reservedMats = parseReservedMats(classData.reservedMats);

      const userRegistrationDoc = await transaction.get(userRegistrationRef);
      if (userRegistrationDoc.exists) {
        throw new HttpsError(
            "already-exists",
            "The user is already registered for this class.",
        );
      }

      const classRegistrationDoc = await transaction.get(classRegistrationRef);
      if (classRegistrationDoc.exists) {
        throw new HttpsError(
            "already-exists",
            "The user is already registered for this class.",
        );
      }

      const standbySnapshot = await transaction.get(standbyQuery);
      const standbyDocs = standbySnapshot.docs;
      const frontStandbyDoc = standbyDocs.length > 0 ? standbyDocs[0] : null;
      const standbyCount = standbyDocs.length;

      if (frontStandbyDoc && frontStandbyDoc.id !== uid) {
        throw new HttpsError(
            "failed-precondition",
            "Standby queue has priority for the next open spot.",
        );
      }

      if (frontStandbyDoc) {
        const userStandbyDoc = await transaction.get(userStandbyRef);
        if (!userStandbyDoc.exists) {
          throw new HttpsError(
              "failed-precondition",
              "Standby queue changed. Try again.",
          );
        }
      }

      if (capacity <= 0 || reservedMats.size >= capacity) {
        throw new HttpsError(
            "failed-precondition",
            "The class is already at full capacity.",
        );
      }

      const assignedMat = pickAvailableMat(capacity, reservedMats);
      if (!assignedMat) {
        throw new HttpsError(
            "failed-precondition",
            "The class is already at full capacity.",
        );
      }

      reservedMats.add(assignedMat);

      const userProfileDoc = await transaction.get(userProfileRef);
      const userProfileData = userProfileDoc.data() || {};
      const userName = buildUserName(userProfileData);
      const userEmail = toTrimmedString(userProfileData.email);

      const registrationData = buildRegistrationData({
        userId: uid,
        userName,
        userEmail,
        classId,
        classData,
        matNumber: assignedMat,
      });
      const rosterData = buildRosterData({
        userId: uid,
        userName,
        userEmail,
        matNumber: assignedMat,
      });

      transaction.set(userRegistrationRef, registrationData);
      transaction.set(classRegistrationRef, registrationData);

      if (frontStandbyDoc) {
        transaction.delete(userStandbyRef);
      }

      const nextStandbyCount = frontStandbyDoc ? standbyCount - 1 : 0;
      transaction.update(classRef, buildClassMetadataUpdate({
        reservedMats,
        capacity,
        standbyCount: nextStandbyCount,
        extraFields: {[`roster.${uid}`]: rosterData},
      }));

      return {
        success: true,
        message: "Successfully registered for the class.",
        matNumber: assignedMat,
      };
    });
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    console.error("Registration Transaction Error:", error);
    throw new HttpsError(
        "internal",
        "An error occurred while processing the registration.",
    );
  }
});

exports.deleteClassFully = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError(
        "unauthenticated",
        "The function must be called while authenticated.",
    );
  }

  const classId = toTrimmedString(request.data?.classId);
  if (!classId) {
    throw new HttpsError(
        "invalid-argument",
        "The function must be called with a valid 'classId'.",
    );
  }

  await assertStaffUser(auth.uid);

  try {
    const {classRef, relatedRefs} = await collectClassRelatedDeleteRefs(classId);
    const classDoc = await classRef.get();

    await classRef.delete();
    await deleteDocumentRefsInBatches(relatedRefs);

    console.log(
        `Fully deleted class ${classId}; deleted ${relatedRefs.length} related docs.`,
    );

    return {
      success: true,
      classExisted: classDoc.exists,
      deletedRelatedDocs: relatedRefs.length,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    console.error("Class deletion error:", error);
    throw new HttpsError(
        "internal",
        "An error occurred while deleting the class.",
    );
  }
});

exports.cleanupDeletedClassData = onDocumentDeleted(
    "classes/{classId}",
    async (event) => {
      const classId = toTrimmedString(event.params.classId);
      if (!classId) {
        return;
      }

      try {
        const {relatedRefs} = await collectClassRelatedDeleteRefs(classId);
        await deleteDocumentRefsInBatches(relatedRefs);

        if (relatedRefs.length > 0) {
          console.log(
              `Cleaned ${relatedRefs.length} orphaned docs for deleted class ${classId}.`,
          );
        }
      } catch (error) {
        console.error("Error cleaning deleted class data:", error);
      }
    },
);

exports.promoteFromStandbyQueue = onDocumentDeleted(
    "classes/{classId}/registrations/{userId}",
    async (event) => {
      const classId = event.params.classId;

      try {
        await db.runTransaction(async (transaction) => {
          const classRef = db.collection("classes").doc(classId);
          const standbyQuery = classRef
              .collection("standby_queue")
              .orderBy("createdAt", "asc");
          const classDoc = await transaction.get(classRef);
          if (!classDoc.exists) {
            return;
          }

          const classData = classDoc.data() || {};
          const capacity = toInt(classData.capacity);
          const reservedMats = parseReservedMats(classData.reservedMats);
          const standbySnapshot = await transaction.get(standbyQuery);
          const standbyDocs = standbySnapshot.docs;
          let remainingStandbyCount = standbyDocs.length;
          const rosterUpdates = {};
          const promotedUsers = [];

          for (const standbyDoc of standbyDocs) {
            if (capacity <= 0 || reservedMats.size >= capacity) {
              break;
            }

            const userId = standbyDoc.id;
            const userRegistrationRef = db.collection("user_profiles")
                .doc(userId)
                .collection("registrations")
                .doc(classId);
            const classRegistrationRef = classRef
                .collection("registrations")
                .doc(userId);

            const userRegistrationDoc = await transaction.get(userRegistrationRef);
            const classRegistrationDoc = await transaction.get(classRegistrationRef);

            if (userRegistrationDoc.exists || classRegistrationDoc.exists) {
              transaction.delete(standbyDoc.ref);
              remainingStandbyCount = Math.max(0, remainingStandbyCount - 1);
              continue;
            }

            const assignedMat = pickAvailableMat(capacity, reservedMats);
            if (!assignedMat) {
              break;
            }

            const userProfileRef = db.collection("user_profiles").doc(userId);
            const userProfileDoc = await transaction.get(userProfileRef);
            const userProfileData = userProfileDoc.data() || {};
            const standbyData = standbyDoc.data() || {};
            const userName =
              toTrimmedString(standbyData.userName) ||
              buildUserName(userProfileData);
            const userEmail =
              toTrimmedString(standbyData.userEmail) ||
              toTrimmedString(userProfileData.email);

            reservedMats.add(assignedMat);
            remainingStandbyCount = Math.max(0, remainingStandbyCount - 1);

            const registrationData = buildRegistrationData({
              userId,
              userName,
              userEmail,
              classId,
              classData,
              matNumber: assignedMat,
            });
            const rosterData = buildRosterData({
              userId,
              userName,
              userEmail,
              matNumber: assignedMat,
            });
            const notificationRef = userProfileRef
                .collection("notifications")
                .doc(`standby-promotion-${classId}`);

            transaction.set(userRegistrationRef, registrationData);
            transaction.set(classRegistrationRef, registrationData);
            transaction.set(notificationRef, {
              title: "Spot opened up",
              message: `You were moved off standby and into ${toTrimmedString(classData.title) || "your class"}. Your mat is ${assignedMat}.`,
              type: "standby_promoted",
              is_read: false,
              class_id: classId,
              created_at: FieldValue.serverTimestamp(),
            }, {merge: true});
            transaction.delete(standbyDoc.ref);

            rosterUpdates[`roster.${userId}`] = rosterData;
            promotedUsers.push(`${userId}:${assignedMat}`);
          }

          transaction.update(classRef, buildClassMetadataUpdate({
            reservedMats,
            capacity,
            standbyCount: remainingStandbyCount,
            extraFields: rosterUpdates,
          }));

          if (promotedUsers.length > 0) {
            console.log(
                `Promoted standby users for class ${classId}: ${promotedUsers.join(", ")}`,
            );
          }
        });
      } catch (error) {
        console.error("Error promoting from standby queue:", error);
      }
    },
);
