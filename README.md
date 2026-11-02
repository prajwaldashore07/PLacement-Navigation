# MITS Placement Navigation Platform

A responsive, database-backed placement-preparation workspace for engineering students. The project uses a vanilla JavaScript/HTML/CSS client, Node.js/Express REST API, and MySQL. It is structured as a demonstration product: every bundled student, company and opportunity is fictional, and application records are not transmitted to employers.

## What is implemented

- Enrollment-number lookup and resumable onboarding for career interests, self-assessed skills (0–10), and private PDF resumes; the final onboarding screen summarizes the saved profile before the dashboard.
- Student dashboard, searchable/filterable opportunity explorer, server-calculated eligibility with explanations for CGPA, branch, batch, academic year, formal active-backlog limits and skill gaps, application tracking, and opportunity-specific recommended tests.
- Timed mock tests across DSA/coding, quantitative aptitude, logical reasoning, verbal ability, technical MCQs, core CS, ETE, technical interviews and HR interviews, with persisted attempts and explained results; ordered roadmaps with topic-linked mini-quizzes; profile/project/achievement/goal editing.
- Role-protected administrator workspace for student academic data (including read-only student backlog facts), opportunity/eligibility criteria, applications, mock tests/questions, learning roadmaps/topics/resources, and audit history.
- Normalized relational MySQL schema, additive migrations, idempotent fictional demo data, shared responsive design components, and focused automated domain tests.

## Prerequisites

- Node.js 22 (the application uses native `fetch` and Node's `.env` file support).
- pnpm 11.25.0, pinned in `package.json`.
- MySQL 8 with a database and a user permitted to create/alter the project's tables.

## Local setup

1. Copy `.env.example` to an ignored `.env` file and set `DATABASE_URL` to a private MySQL connection string. For a local, plain-HTTP browser, keep `SESSION_COOKIE_SECURE=false` and `SESSION_COOKIE_SAMESITE=lax` as in the example. Do not commit `.env`.
2. Install dependencies and initialize the schema/demo data:

   ```bash
   pnpm install --frozen-lockfile
   pnpm db:migrate
   pnpm db:seed
   ```

3. Start the server:

   ```bash
   pnpm dev
   ```

   Open `http://localhost:3000`. The app also runs the migration and idempotent seed scripts during server startup. They add missing demo records and do not reset student progress or overwrite administrator-edited opportunity criteria. `PORT` may select another listener port.

4. Run the automated business-logic checks:

   ```bash
   pnpm test
   ```

   `pnpm check` is a lightweight entry-point syntax check; a complete syntax scan can be run with:

   ```bash
   find client server database tests -type f -name '*.js' -print0 | xargs -0 -n1 node --check
   ```

## Demo student access

Enrollment lookup resolves records from MySQL and returns the official name, branch, academic year, graduation batch, CGPA and recorded active-backlog count; students cannot supply or change these academic facts. A seeded example enrollment number is `BTET24O1091`. The login is deliberately enrollment-number-only to match the requested fictional demo workflow. **It is not secure authentication**: anyone who knows an included enrollment number can act as that fictional student. Do not import real student records or use this access model for a real deployment. Before handling real students, replace the demo endpoint with the institution's approved identity provider or another verified authentication flow, enforce account lifecycle and access controls, and review privacy/retention requirements.

## Administrator bootstrap

The site ships no default administrator account or password. After `pnpm db:migrate`, set `ADMIN_SEED_EMAIL`, `ADMIN_SEED_NAME`, and `ADMIN_SEED_PASSWORD` in the private environment. Use a unique password of at least 12 characters. Then run:

```bash
pnpm admin:seed
```

The script stores a bcrypt-hashed password and creates the record only if that email does not already exist; it never replaces an existing password. Sign in at `/admin/login`. In a hosted environment, provision the admin variables as protected runtime secrets and run the bootstrap only as an authorized operator. Do not place an administrator password in source control, browser code, a public task description, or a production image.

## Environment and security

- `DATABASE_URL`: MySQL URI supplied by Webdev in managed development/deployment; local installations configure their own.
- `PORT`: HTTP listener (default `3000`).
- `SESSION_COOKIE_SECURE` and `SESSION_COOKIE_SAMESITE`: local HTTP uses `false`/`lax`; public HTTPS Preview/production must use `true`/`none` so the session works inside the cross-site Preview iframe. The app does not infer secure cookies from the server-side proxy connection.
- `SESSION_TTL_HOURS`: session lifetime (default 12; capped at seven days).
- `MAX_RESUME_BYTES`: upload limit in bytes (default 5 MiB; capped at 10 MiB).
- `ADMIN_SEED_EMAIL`, `ADMIN_SEED_NAME`, `ADMIN_SEED_PASSWORD`: used only by the explicit administrator bootstrap command. No defaults are provided for credentials.
- `MANUS_API_URL` and `MANUS_API_KEY`: project-provided server-side runtime credentials used for durable private resume object storage. Do not expose these to the browser.

Session cookies are HTTP-only, opaque random tokens are stored as SHA-256 hashes in MySQL, writes use a per-session CSRF token, logins are rate limited, admin APIs enforce server-verified roles, and SQL values use prepared statements. Resume bytes are uploaded through the managed private storage API; every preview/download checks the signed-in owner and uses `private, no-store`. Removing a resume hides it from the active profile and future applications. The runtime storage API does not provide object deletion, so this action does **not** promise physical erasure; physical cleanup requires an authorized storage-operator deletion path.

## MySQL schema, migrations and seed data

`database/schema.sql` defines the normalized tables and indexes, including academic facts, company-specific rule rows and the opportunity/topic-to-test relationships. `database/migrations/` contains ordered additive changes recorded in `schema_migrations`; it does not drop existing user data. `database/seed.js` creates at least 200 fictional student profiles, at least 20 fictional opportunities, varied active-backlog facts, associated criteria, role-specific test recommendations, mock tests/questions and learning roadmaps/resources with linked mini-quizzes. Seeds use stable identifiers and insert missing fictional records; they never reset student progress. On first creation, each listing's branch, academic-year, skill and stage relationships are populated; later startups preserve administrator edits.

The managed MySQL database is shared by development and published use. Do not run destructive experiments or truncate/delete production tables while testing. Migrations and seed scripts are additive/non-destructive; avoid using a real institution's data in the fictional environment.

## Development and deployment

The Express service serves `public/` and `client/`, all `/api` endpoints, the static `GET /manus-routes.json`, and an unauthenticated `GET /health` readiness endpoint. Run in production with `pnpm start`; a database initialization error leaves `/health` non-ready and is logged without including raw database credentials or messages.

The root `Dockerfile` uses Node 22, installs the production dependencies from the pnpm lockfile, listens on `PORT` (default 3000), and starts `server/index.js`. A container deployment needs a runtime MySQL URL and private session cookie settings; configure an administrator bootstrap secret only when creating the first administrator. The project uses the managed MySQL database and the platform-provided runtime storage credentials. Container-local files are ephemeral; student resumes are not stored on the container filesystem. Configure `/health` as the deployment health check. Preview and production use HTTPS cookies: set `SESSION_COOKIE_SECURE=true` and `SESSION_COOKIE_SAMESITE=none` in the hosted runtime.

Employer submission, live company verification, real email/SMS notifications and institution identity-provider integration are not implemented. The application tracker records student activity only. Coding-test code execution is also not provided; any coding exercise would require manual evaluation unless a separate, safely isolated execution service is added.

## REST API overview

All API requests use same-origin JSON. The app obtains a CSRF token from `GET /api/session` after authentication and includes it on state-changing requests.

| Area | Endpoint group |
| --- | --- |
| Authentication | `POST /api/auth/enrollment`, `POST /api/auth/admin`, `GET /api/session`, `DELETE /api/auth/logout` |
| Student onboarding/profile | `/api/student/onboarding`, `/api/student/interests`, `/api/student/skills`, `/api/student/profile`, `/api/student/dashboard`, `/api/student/resume` |
| Opportunities | `GET /api/companies`, `GET /api/companies/:id` (search, package/location/domain/branch/status/CGPA/deadline filters are computed against current MySQL records) |
| Application tracker | `POST /api/companies/:id/apply`, `/api/applications`, `PATCH /api/applications/:id/withdraw` |
| Mock tests | `/api/preparation/tests`, `/api/preparation/recommendations?opportunityId=…` or `?domain=…`, `/api/tests/:id`, `/api/tests/:id/attempts`, `/api/attempts/:id`, `/api/attempts/:id/answers`, `/api/attempts/:id/submit`, `/api/attempts/:id/results` |
| Student learning | `GET /api/learning` (roadmaps, topic progress, resources and linked quick quizzes), `PATCH /api/learning/topics/:id` |
| Administration | `/api/admin/dashboard`, `/api/admin/students`, `/api/admin/opportunities`, `/api/admin/applications`, `/api/admin/tests`, `/api/admin/questions`, `/api/admin/learning` (plus nested create/edit/archive routes for each supported content type) |

## Troubleshooting

- **Database connection fails:** verify the MySQL URI, TLS/host access and account privileges. In managed Webdev, check that the project database capability is enabled and that `DATABASE_URL` is present. The startup health endpoint remains at 503 until schema initialization and seeding complete.
- **Session does not survive local reload:** use local HTTP cookie settings `secure=false`, `sameSite=lax`; do not copy those values to HTTPS Preview. Preview requires `secure=true`, `sameSite=none`, although browser third-party-cookie policies may still affect embedded sessions.
- **Resume upload reports storage unavailable:** confirm the managed runtime supplies `MANUS_API_URL` and `MANUS_API_KEY`. The app never falls back to public URLs or container disk.
- **Administrator sign-in is unavailable:** create a bootstrap account with the private environment variables and `pnpm admin:seed`; there is no shipped default login.
- **Existing schema does not have a new criterion:** run `pnpm db:migrate` before seeding. Applied migrations are recorded and reruns skip them safely.
- **An opportunity is not listed:** administrators may pause/close it; student-facing listings include active opportunities only. Expired active listings remain visible with a “Deadline Passed” explanation.
