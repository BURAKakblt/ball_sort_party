// Firestore Security Rules tests (Emulator Suite required).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, serverTimestamp, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ball-sort-party',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const progress = (over = {}) => ({
  schema: 1,
  unlockedLevel: 3,
  levels: { 1: { stars: 3, sig: 'x' }, 2: { stars: 1, sig: 'x' } },
  runs: {},
  updatedAtMs: 1,
  deviceId: 'abc',
  serverUpdatedAt: serverTimestamp(),
  ...over,
});
const db = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();
const progressDoc = (uid, owner = uid) => doc(db(uid), `users/${owner}/progress/main`);

test('owner can create and read own progress', async () => {
  await assertSucceeds(setDoc(progressDoc('alice'), progress()));
  await assertSucceeds(getDoc(progressDoc('alice')));
});

test('nobody can read or write someone else\'s progress', async () => {
  await assertSucceeds(setDoc(progressDoc('alice'), progress()));
  await assertFails(getDoc(progressDoc('bob', 'alice')));
  await assertFails(setDoc(progressDoc('bob', 'alice'), progress()));
  await assertFails(getDoc(progressDoc(null, 'alice')));
});

test('progress cannot go backwards', async () => {
  await assertSucceeds(setDoc(progressDoc('alice'), progress({ unlockedLevel: 10 })));
  await assertFails(setDoc(progressDoc('alice'), progress({ unlockedLevel: 4 })));
  await assertFails(setDoc(progressDoc('alice'), progress({ unlockedLevel: 10, levels: { 1: { stars: 3, sig: 'x' } } })));
  await assertSucceeds(setDoc(progressDoc('alice'), progress({ unlockedLevel: 11 })));
});

test('economy fields cannot be smuggled into progress', async () => {
  await assertFails(setDoc(progressDoc('alice'), progress({ coins: 999999 })));
  await assertFails(setDoc(progressDoc('alice'), progress({ lives: 99 })));
});

test('invalid progress is rejected', async () => {
  await assertFails(setDoc(progressDoc('alice'), progress({ unlockedLevel: 99 })));
  await assertFails(setDoc(progressDoc('alice'), progress({ levels: { 51: { stars: 3, sig: 'x' } } })));
  await assertFails(setDoc(progressDoc('alice'), progress({ schema: 2 })));
  await assertFails(setDoc(progressDoc('alice'), progress({ serverUpdatedAt: 5 })));
  await assertFails(setDoc(doc(db('alice'), 'users/alice/progress/other'), progress()));
});

test('progress cannot be deleted', async () => {
  await assertSucceeds(setDoc(progressDoc('alice'), progress()));
  await assertFails(deleteDoc(progressDoc('alice')));
});

test('economy and purchases are read-only for the player', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/alice/economy/state'), { coins: 200, lives: 5 });
    await setDoc(doc(ctx.firestore(), 'users/alice/purchases/p1'), { sku: 'coins_1000' });
  });
  await assertSucceeds(getDoc(doc(db('alice'), 'users/alice/economy/state')));
  await assertFails(updateDoc(doc(db('alice'), 'users/alice/economy/state'), { coins: 999999 }));
  await assertFails(setDoc(doc(db('alice'), 'users/alice/economy/state'), { coins: 1 }));
  await assertFails(setDoc(doc(db('alice'), 'users/alice/purchases/p2'), { sku: 'free' }));
  await assertFails(getDoc(doc(db('bob'), 'users/alice/economy/state')));
});

test('profile and unknown collections are closed', async () => {
  await assertFails(setDoc(doc(db('alice'), 'users/alice'), { name: 'x' }));
  await assertFails(setDoc(doc(db('alice'), 'leaderboard/alice'), { score: 1 }));
  await assertFails(getDoc(doc(db('alice'), 'users/alice/secret/x')));
});
