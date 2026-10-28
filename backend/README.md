# FixOnWay backend

Node.js + Express + MongoDB (Mongoose). See the project README for setup.

## Scripts
| Command | What it does |
|---|---|
| `npm start` | run the API |
| `npm run dev` | run and restart on file changes |
| `npm run seed` | demo accounts and sample data (empties the database; `-- --keep` to keep it) |
| `npm test` | helper, routing and validation tests (+ database flow if `MONGODB_TEST_URI` is set) |

## API (all under /api, JSON; login token in `Authorization: Bearer <token>`)
| Route | Who | Purpose |
|---|---|---|
| `GET /health` | anyone | is the server up |
| `POST /auth/exists` `/auth/register` `/auth/login` `/auth/reset-password` | anyone | accounts |
| `GET /auth/me`, `PUT /auth/profile`, `POST /auth/change-password` | logged in | my account |
| `GET /users`, `PATCH /users/:id/status`, `PATCH /users/:id/verification` | admin | UC-34..36 |
| `/requests`, `/estimates`, `/mechanics`, `/notifications`, `/vehicles` | logged in (rules per route) | the app's data |
| `/messages?requestId=` | the customer and mechanic of the job | chat |
| `/reviews`, `/complaints` | logged in (rules per route) | UC-19, 22, 33, 38 |
| `/applications` | the mechanic (own), admin | verification forms |
| `/audit` | admin | activity log |
| `PUT/GET /live/:requestId` | assigned mechanic writes, job members read | live GPS |

Collections store the same JSON the Flutter app uses (dates as epoch milliseconds), with `id` instead of `_id`.
Access rules live in `src/routes/data.js`, the shared list/get/create/replace/delete code in `src/resource.js`.
