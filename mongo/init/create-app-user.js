const appUser = 'chatfleet';
const appPass = process.env.MONGO_APP_PASSWORD;
if (!appPass) {
  print('ERROR: MONGO_APP_PASSWORD not set');
} else {
  db = db.getSiblingDB('chatfleet');
  db.createUser({ user: appUser, pwd: appPass, roles: [ { role: 'readWrite', db: 'chatfleet' } ] });
  print('Created application user: chatfleet');
}

