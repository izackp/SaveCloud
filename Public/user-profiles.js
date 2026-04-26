(function () {
    const createForm = document.getElementById("create_form");
    const createIdInput = document.getElementById("create_profile_id");
    const createAvatarContainer = document.getElementById("create_profile_avatar_container");
    const shuffleButton = document.getElementById("shuffle_button");
    if (!createForm || !createIdInput || !createAvatarContainer || !shuffleButton) {
        return;
    }

    const initialId = "2D2F6D2A-7D14-4554-B8A4-B47D3CDD0001";
    let currentId = createIdInput.value || initialId;

    function renderProfileId(value) {
        const normalizedValue = value.toUpperCase();
        currentId = normalizedValue;
        createIdInput.value = normalizedValue;
        createAvatarContainer.innerHTML =
            '<' + 'svg width="80" height="80" data-jdenticon-value="' + normalizedValue + '"></' + 'svg>';
        if (window.jdenticon && createAvatarContainer.firstElementChild) {
            window.jdenticon.update(createAvatarContainer.firstElementChild);
        }
    }

    function shuffleProfileId() {
        renderProfileId(crypto.randomUUID());
    }

    createForm.addEventListener("submit", function () {
        if (!createIdInput.value) {
            renderProfileId(currentId || initialId);
        } else {
            createIdInput.value = currentId;
        }
    });

    renderProfileId(currentId);
    shuffleButton.addEventListener("click", shuffleProfileId);
}());
