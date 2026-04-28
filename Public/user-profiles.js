(function () {
    const createForm = document.getElementById("create_form");
    const createIdInput = document.getElementById("create_profile_id");
    const createAvatarContainer = document.getElementById("create_profile_avatar_container");
    const shuffleButton = document.getElementById("shuffle_button");
    if (!createForm || !createIdInput || !createAvatarContainer || !shuffleButton) {
        return;
    }

    const initialId = "";
    let currentId = createIdInput.value || initialId;

    function randomSmallUid() {
        const timestamp = BigInt(Date.now());
        const randomBytes = new Uint32Array(1);
        crypto.getRandomValues(randomBytes);
        const random = BigInt(randomBytes[0] & 0xFFFFF);
        const value = (timestamp << 20n) | random;

        const bytes = new Uint8Array(8);
        let remaining = value;
        for (let index = 7; index >= 0; index -= 1) {
            bytes[index] = Number(remaining & 0xFFn);
            remaining >>= 8n;
        }

        let binary = "";
        bytes.forEach(function (byte) {
            binary += String.fromCharCode(byte);
        });
        return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
    }

    function renderProfileId(value) {
        currentId = value;
        createIdInput.value = value;
        createAvatarContainer.innerHTML =
            '<' + 'svg width="80" height="80" data-jdenticon-value="' + value + '"></' + 'svg>';
        if (window.jdenticon && createAvatarContainer.firstElementChild) {
            window.jdenticon.update(createAvatarContainer.firstElementChild);
        }
    }

    function shuffleProfileId() {
        renderProfileId(randomSmallUid());
    }

    createForm.addEventListener("submit", function () {
        if (!createIdInput.value) {
            renderProfileId(currentId || randomSmallUid());
        } else {
            createIdInput.value = currentId;
        }
    });

    renderProfileId(currentId || randomSmallUid());
    shuffleButton.addEventListener("click", shuffleProfileId);
}());
