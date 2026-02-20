import { ajax } from "discourse/lib/ajax";

function jsonPath(path) {
  return path.endsWith(".json") ? path : `${path}.json`;
}

export function listCollections({ filter = "latest", q = "" } = {}) {
  return ajax(jsonPath("/collections"), {
    data: {
      filter,
      q,
    },
  });
}

export function listMyCollections({
  scope = null,
  q = "",
  containsTopicId = null,
  containsPostId = null,
} = {}) {
  return ajax(jsonPath("/collections/mine"), {
    data: {
      scope,
      q,
      contains_topic_id: containsTopicId,
      contains_post_id: containsPostId,
    },
  });
}

export function listUserCollections(username, { q = "" } = {}) {
  return ajax(jsonPath(`/collections/user/${encodeURIComponent(username)}`), {
    data: { q },
  });
}

export function fetchCollection(collectionId) {
  return ajax(jsonPath(`/collections/${collectionId}`));
}

export function fetchRoleEvents(collectionId) {
  return ajax(jsonPath(`/collections/${collectionId}/role-events`));
}

export function createCollection(title, description = "") {
  return ajax(jsonPath("/collections"), {
    type: "POST",
    data: {
      collection: {
        title,
        description,
      },
    },
  });
}

export function updateCollection(collectionId, { title, description }) {
  return ajax(jsonPath(`/collections/${collectionId}`), {
    type: "PUT",
    data: {
      collection: {
        title,
        description,
      },
    },
  });
}

export function deleteCollection(collectionId) {
  return ajax(jsonPath(`/collections/${collectionId}`), {
    type: "DELETE",
  });
}

export function addCollectionItem(collectionId, { topicId, postId, note }) {
  const data = { note };
  if (postId) {
    data.post_id = postId;
  } else {
    data.topic_id = topicId;
  }

  return ajax(jsonPath(`/collections/${collectionId}/items`), {
    type: "POST",
    data,
  });
}

export function removeCollectionItem(collectionId, itemId) {
  return ajax(jsonPath(`/collections/${collectionId}/items/${itemId}`), {
    type: "DELETE",
  });
}

export function moveCollectionItem(collectionId, itemId, position) {
  return ajax(jsonPath(`/collections/${collectionId}/items/${itemId}/move`), {
    type: "PUT",
    data: { position },
  });
}

export function inviteMaintainer(
  collectionId,
  { userId = null, username = "", note = "" } = {}
) {
  const data = { note };
  if (userId) {
    data.user_id = userId;
  } else if (username?.trim()) {
    data.username = username.trim();
  }

  return ajax(jsonPath(`/collections/${collectionId}/maintainers/invite`), {
    type: "POST",
    data,
  });
}

export function applyMaintainer(collectionId, note = "") {
  return ajax(jsonPath(`/collections/${collectionId}/maintainers/apply`), {
    type: "POST",
    data: { note },
  });
}

export function approveMaintainer(collectionId, userId) {
  return ajax(jsonPath(`/collections/${collectionId}/maintainers/${userId}/approve`), {
    type: "PUT",
  });
}

export function rejectMaintainer(collectionId, userId) {
  return ajax(jsonPath(`/collections/${collectionId}/maintainers/${userId}/reject`), {
    type: "PUT",
  });
}

export function removeMaintainer(collectionId, userId) {
  return ajax(jsonPath(`/collections/${collectionId}/maintainers/${userId}`), {
    type: "DELETE",
  });
}

export function transferOwnership(
  collectionId,
  { newOwnerUserId = null, newOwnerUsername = "" } = {}
) {
  const data = {};
  if (newOwnerUserId) {
    data.new_owner_user_id = newOwnerUserId;
  } else if (newOwnerUsername?.trim()) {
    data.new_owner_username = newOwnerUsername.trim();
  }

  return ajax(jsonPath(`/collections/${collectionId}/owner`), {
    type: "PUT",
    data,
  });
}

export function followCollection(collectionId) {
  return ajax(jsonPath(`/collections/${collectionId}/follow`), {
    type: "POST",
  });
}

export function unfollowCollection(collectionId) {
  return ajax(jsonPath(`/collections/${collectionId}/follow`), {
    type: "DELETE",
  });
}
