# RoomEase Bruno API Tests

Rebuilt and organized by API domain. All files are under `api-tests` and can be run folder-by-folder.

## Run in Bruno app
1. Start backend server.
2. Open folder `bruno-tests` in Bruno.
3. Select environment `Local`.
4. Put a valid `firebase_token` in `environments/Local.bru`.
5. Run `api-tests/01-auth-public/post_api_auth_login.bru` first.
6. Then run folders in order `00` to `12`.
7. For parameterized endpoints, set vars like `roomspace_id`, `user_id`, `payment_id`, `template_id`, `notification_id`, `code`.

## Note
Bruno CLI (`bru`) is not installed in this environment, so run these from Bruno desktop app.
