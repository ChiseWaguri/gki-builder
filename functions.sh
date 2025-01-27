#!/usr/bin/env bash
upload_file() {
    local user_file="$1"
    local msg="$2"
        ### sendDocument -- https://core.telegram.org/bots/api#senddocument
### sendDocument -- https://core.telegram.org/bots/api#senddocument
    curl -sL  \
        -o log.txt \
        -F document=@"$user_file" \
        -F chat_id="$chat_id" \
        -F parse_mode="HTML" \
        -F caption="$msg" \
        -X POST \
        https://api.telegram.org/bot$token/sendDocument
}


send_msg() {
    local msg="$1"
    curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
        -d chat_id="$chat_id" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="$msg" \
        -o /dev/null
}


release_gh() {
    ## Release into GitHub
    TAG="$BUILD_DATE"
    RELEASE_MESSAGE="${ZIP_NAME%.zip}"
    DOWNLOAD_URL="$GKI_RELEASES_REPO/releases/download/$TAG/$ZIP_NAME"

    GITHUB_USERNAME=$(echo "$GKI_RELEASES_REPO" | awk -F'https://github.com/' '{print $2}' | awk -F'/' '{print $1}')
    REPO_NAME=$(echo "$GKI_RELEASES_REPO" | awk -F'https://github.com/' '{print $2}' | awk -F'/' '{print $2}')

    # Create a release tag
    $WORKDIR/../github-release release \
        --security-token "$gh_token" \
        --user "$GITHUB_USERNAME" \
        --repo "$REPO_NAME" \
        --tag "$TAG" \
        --name "$RELEASE_MESSAGE"

    sleep 5

    # Upload the kernel zip
    $WORKDIR/../github-release upload \
        --security-token "$gh_token" \
        --user "$GITHUB_USERNAME" \
        --repo "$REPO_NAME" \
        --tag "$TAG" \
        --name "$ZIP_NAME" \
        --file "$WORKDIR/$ZIP_NAME" || failed=yes

    if [[ $failed == "yes" ]]; then
        send_msg "❌ Failed to release into GitHub"
        exit 1
    else
        send_msg "📦 [Download]($DOWNLOAD_URL)"
    fi
}



