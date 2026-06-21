# AGENTS.md

## Project

KWMS is an enterprise-grade warehouse management system used by major corporations.

- `frontend/`: Flutter web/mobile app.
- `backend/`: FastAPI backend.
- `deploy/`: deployment-related files.

## Working Rules

- Keep `README.md` as human-facing project documentation.
- Use this file for Codex/agent workflow instructions.
- Do not store passwords, API keys, DB credentials, or SFTP credentials in repository files.
- Do not revert unrelated local changes. This workspace may contain in-progress user changes.

## Frontend

Run Flutter commands from `frontend/`.

```bash
cd frontend
flutter analyze
flutter test
flutter build web --release
```

- Use the existing Flutter UI patterns and KWMS design language.
- Keep Korean business labels consistent with the current screens.
- For numeric, quantity, amount, and measurement fields, use shared input formatters instead of ad hoc validation in each screen.
- After frontend changes, verify with `flutter analyze` and `flutter test`.
- For web delivery, build with `flutter build web --release`.

## Backend

Run backend commands from `backend/`.

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -e .
uvicorn app.main:app --reload
```

- Keep API and database changes backward-compatible when possible.
- Do not hard-code production credentials.

## Deployment

- Deploy frontend web output from `frontend/build/web`.
- Production host is `www.metaseoul.net`.
- Production verification target is `http://www.metaseoul.net`.
- Always deploy completed application changes to `www.metaseoul.net` by SFTP before reporting the task as complete.
- Do not commit or write SFTP credentials to repository files; load credentials from the local environment or another secure local source.
- After every SFTP deployment, test the live site at `http://www.metaseoul.net`.
- Do not mark the task complete until the SFTP deployment has succeeded and the live production test has passed.
- If SFTP deployment or live production testing fails, report the task as not complete and include the exact blocker.

## Verification

For ordinary frontend changes, use:

```bash
cd frontend
flutter analyze
flutter test
flutter build web --release
```

- After the release build succeeds, deploy `frontend/build/web` to `www.metaseoul.net` by SFTP.
- Verify the deployed site at `http://www.metaseoul.net` before final completion.

For docs-only changes, tests are not required.
