const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');

initializeApp();

exports.notifyFamilyInvitation = onDocumentCreated(
  'familyInvitations/{invitationId}',
  async (event) => {
    const invitation = event.data?.data();
    if (!invitation || invitation.status !== 'pending' || !invitation.toUid) {
      return;
    }

    const tokenCollection = getFirestore()
      .collection('users')
      .doc(invitation.toUid)
      .collection('deviceTokens');
    const tokenSnapshot = await tokenCollection.get();
    const registrations = tokenSnapshot.docs
      .map((document) => ({ id: document.id, token: document.data().token }))
      .filter((registration) => typeof registration.token === 'string');
    if (registrations.length === 0) return;

    const name = invitation.fromName || 'Someone';
    const response = await getMessaging().sendEachForMulticast({
      tokens: registrations.map((registration) => registration.token),
      notification: {
        title: 'New family request',
        body: `${name} wants to join your family circle.`,
      },
      data: {
        type: 'family_invitation',
        invitationId: event.params.invitationId,
      },
      android: { priority: 'high' },
    });

    const staleTokens = [];
    response.responses.forEach((result, index) => {
      if (
        !result.success &&
        ['messaging/registration-token-not-registered', 'messaging/invalid-registration-token']
          .includes(result.error?.code)
      ) {
        staleTokens.push(registrations[index].id);
      }
    });

    if (staleTokens.length > 0) {
      const batch = getFirestore().batch();
      staleTokens.forEach((tokenId) => batch.delete(tokenCollection.doc(tokenId)));
      await batch.commit();
    }
  },
);