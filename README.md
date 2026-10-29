# FixOnWay - on-demand roadside assistance (Pakistan)

Flutter app (Customer / Mechanic / Admin) + **Node.js + Express + MongoDB** backend.

```
fixonway/
  backend/   Express REST API, MongoDB (Mongoose), JWT login, seed data, tests
  lib/       Flutter app: screens -> controllers -> services -> repositories -> API
  test/      Flutter unit and widget tests
```

## How it fits together
`screens -> controllers (Provider) -> services (business rules) -> repositories -> ApiClient -> Express -> MongoDB`

- The repositories are interfaces. `Api*Repository` talks to the backend, `Mock*Repository` keeps everything in memory.
- `lib/main.dart` picks the API by default. `--dart-define=USE_MOCK=true` runs without any backend.
- The backend checks who is calling (JWT) and what they may touch, in `backend/src/routes/data.js`
  (customers see only their requests and vehicles, chat only for the two people of a job, admin-only areas, ...).
- Passwords are hashed with bcrypt. Five wrong passwords lock the account for 15 minutes.

## Setup (Windows)

### 1. MongoDB (pick one)
**A. MongoDB Atlas (free, online)**
1. mongodb.com/cloud/atlas > sign up > create a free **M0** cluster.
2. *Database Access* > Add user (username + password, no special characters is easiest).
3. *Network Access* > Add IP address > **Allow access from anywhere** (0.0.0.0/0) for the lab project.
4. *Database* > Connect > Drivers > copy the string, e.g.
   `mongodb+srv://USER:PASSWORD@cluster0.xxxxx.mongodb.net/fixonway?retryWrites=true&w=majority`
   (put `/fixonway` before the `?` so the database is called fixonway).

**B. Local MongoDB**
Install *MongoDB Community Server* (it runs as a Windows service) and optionally *MongoDB Compass*.
The address is `mongodb://127.0.0.1:27017/fixonway`.

### 2. Backend
Install Node.js LTS from nodejs.org, then in the `backend` folder:
```
copy .env.example .env
notepad .env          (paste your MONGODB_URI, change JWT_SECRET to any long text)
npm install
npm run seed          (demo accounts and sample data)
npm start             (API on http://localhost:5000, check http://localhost:5000/api/health)
```
Keep this window open while you use the app. `npm run dev` restarts the server when you edit a file.

### 3. Flutter app
```
flutter pub add http shared_preferences
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```
The app calls `http://localhost:5000` by default. Another address:
`flutter run -d chrome --dart-define=API_URL=https://your-server`.

## Demo accounts (after `npm run seed`)
| Role | Login | Password |
|---|---|---|
| Customer | ali.raza@example.pk / 0300 1234567 | Pass@1234 |
| Mechanic (verified) | usman@example.pk | Pass@1234 |
| Admin | sara.khan@fixonway.pk | Admin@1234 |
| Pending mechanic | zahid@example.pk | Pass@1234 |
| Blocked | blocked@example.pk | Pass@1234 |

`npm run seed` empties the database first; `npm run seed -- --keep` keeps what is there.

## Photos and documents
Problem photos (customer) and verification documents (mechanic: CNIC front/back, licence, workshop photo, certificate)
are picked in the app and uploaded to the backend, which keeps them in MongoDB (collection `files`, free, no other service).
- Pictures only (JPG, PNG, WEBP, GIF), up to 5 MB. The backend checks the file really is a picture.
- Documents are private: only the mechanic who uploaded them and the admin can open them (admin: Approvals tab, tap a document).
- Photos can be opened by anyone who has the link (the id is random).
In mock mode (`USE_MOCK=true`) uploads are only simulated.

## Tests
- Flutter: `flutter test` (validators, state machine, services, codecs, API client with a fake server, widgets).
- Backend: `cd backend && npm test` (helpers, routing, validation). The full database flow runs when you set
  `MONGODB_TEST_URI` (a throw-away database, it is emptied!):
  `set MONGODB_TEST_URI=mongodb://127.0.0.1:27017/fixonway_test` then `npm test`.

## Still demo on purpose
Phone verification code (removed), JazzCash/EasyPaisa (payment is recorded only), push notifications when the app is closed.
"Forgot password" accepts the phone number alone. That is fine for the lab but must get a real e-mail or SMS check before
real use.
