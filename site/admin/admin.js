// FoodFat · Admin web app
// Mirrors lib/screens/admin*.dart against the same Firestore data model.

import { initializeApp } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-app.js";
import {
  getAuth, onAuthStateChanged,
  signInWithEmailAndPassword, createUserWithEmailAndPassword,
  signInWithPopup, GoogleAuthProvider, OAuthProvider,
  signInWithPhoneNumber, RecaptchaVerifier,
  sendPasswordResetEmail, updateProfile, signOut,
} from "https://www.gstatic.com/firebasejs/10.13.2/firebase-auth.js";
import {
  getFirestore, collection, doc, getDoc, setDoc, deleteDoc, addDoc,
  onSnapshot, query, where, orderBy, limit, serverTimestamp,
  Timestamp, getCountFromServer, writeBatch,
} from "https://www.gstatic.com/firebasejs/10.13.2/firebase-firestore.js";

// ---------------------------------------------------------------- Firebase
// Config below uses the iOS app's public Firebase keys. They are safe to
// expose (security is enforced by Firestore rules + Auth), but you should
// register a dedicated Web app in the Firebase Console for proper analytics
// + per-platform key restrictions, and replace `appId` with the web one.
const firebaseConfig = {
  apiKey: "AIzaSyAkX9hNOBt6J6kqeNJJSGlnaXtNUYIXXek",
  authDomain: "foodfat.firebaseapp.com",
  projectId: "foodfat",
  storageBucket: "foodfat.firebasestorage.app",
  messagingSenderId: "936097862983",
  appId: "1:936097862983:web:placeholder",
};

const app  = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db   = getFirestore(app);

// ---------------------------------------------------------------- DOM refs
const $ = (id) => document.getElementById(id);
const authScreen   = $("auth-screen");
const deniedScreen = $("denied-screen");
const adminScreen  = $("admin-screen");
const authForm     = $("auth-form");
const authError    = $("auth-error");
const who          = $("who");
const signoutBtn   = $("signout");
const deniedSignout= $("denied-signout");
const deniedUid    = $("denied-uid");

// ---------------------------------------------------------------- Helpers
function show(el) { el.hidden = false; }
function hide(el) { el.hidden = true; }
function toast(msg, kind="ok") {
  const t = $("toast");
  t.textContent = msg;
  t.style.background = kind === "err" ? "var(--bad)" : "var(--ink)";
  show(t);
  clearTimeout(toast._t);
  toast._t = setTimeout(() => hide(t), 2400);
}
function rel(date) {
  if (!date) return "";
  const diff = (Date.now() - date.getTime()) / 1000;
  if (diff < 60)   return "just now";
  if (diff < 3600) return `${Math.floor(diff/60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff/3600)}h ago`;
  if (diff < 604800) return `${Math.floor(diff/86400)}d ago`;
  return `${Math.floor(diff/604800)}w ago`;
}
function isLive(ad, now=new Date()) {
  if (!ad.enabled) return false;
  if (ad.startsAt && now < ad.startsAt) return false;
  if (ad.endsAt   && now > ad.endsAt)   return false;
  return true;
}
function esc(s) {
  return (s ?? "").toString().replace(/[&<>"']/g, (c)=>({
    "&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#39;"
  }[c]));
}

// ---------------------------------------------------------------- Auth flow
// Tab toggle ----------------------------------------------------------------
let authMode = "signin"; // or "signup"
function setAuthMode(mode) {
  authMode = mode;
  document.querySelectorAll(".auth-tab").forEach((t) => {
    t.classList.toggle("is-active", t.dataset.mode === mode);
  });
  const isSignup = mode === "signup";
  $("auth-submit").textContent = isSignup ? "Create account" : "Sign in";
  $("display-name-field").hidden = !isSignup;
  $("password-confirm-field").hidden = !isSignup;
  $("password").autocomplete = isSignup ? "new-password" : "current-password";
}
document.querySelectorAll(".auth-tab").forEach((t) => {
  t.addEventListener("click", () => setAuthMode(t.dataset.mode));
});

// Email submit (handles both sign-in + sign-up) ------------------------------
authForm.addEventListener("submit", async (ev) => {
  ev.preventDefault();
  hide(authError);
  const email = $("email").value.trim();
  const pw    = $("password").value;
  const btn   = $("auth-submit");
  btn.disabled = true;
  try {
    if (authMode === "signup") {
      const confirm = $("password-confirm").value;
      if (pw !== confirm) throw new Error("Passwords don't match.");
      const cred = await createUserWithEmailAndPassword(auth, email, pw);
      const name = $("display-name").value.trim();
      if (name) await updateProfile(cred.user, { displayName: name });
      toast("Account created — checking admin status…");
    } else {
      await signInWithEmailAndPassword(auth, email, pw);
    }
  } catch (e) {
    authError.textContent = humanise(e);
    show(authError);
  } finally {
    btn.disabled = false;
  }
});

// OAuth providers -----------------------------------------------------------
async function popupAuth(provider, label) {
  hide(authError);
  try {
    await signInWithPopup(auth, provider);
  } catch (e) {
    if (e?.code === "auth/popup-closed-by-user") return;
    if (e?.code === "auth/operation-not-allowed") {
      authError.textContent = `${label} sign-in isn't enabled in Firebase Console → Authentication → Sign-in method. Turn it on and try again.`;
    } else {
      authError.textContent = humanise(e);
    }
    show(authError);
  }
}
$("prov-google").addEventListener("click", () => popupAuth(new GoogleAuthProvider(), "Google"));
$("prov-apple").addEventListener("click", () => {
  const p = new OAuthProvider("apple.com");
  p.addScope("email"); p.addScope("name");
  popupAuth(p, "Apple");
});

// Phone auth (two-step) -----------------------------------------------------
const phoneModal = $("phone-modal");
let phoneVerifier = null;
let phoneConfirmation = null;
function showPhoneStep(n) {
  $("phone-step-1").hidden = n !== 1;
  $("phone-step-2").hidden = n !== 2;
  $("phone-step-label").textContent = `Step ${n} / 2`;
  hide($("phone-error"));
}
$("prov-phone").addEventListener("click", () => {
  show(phoneModal);
  showPhoneStep(1);
  $("phone-number").value = "";
  $("phone-code").value = "";
  if (!phoneVerifier) {
    try {
      phoneVerifier = new RecaptchaVerifier(auth, "recaptcha-container", { size: "normal" });
      phoneVerifier.render();
    } catch (e) {
      $("phone-error").textContent = "reCAPTCHA failed to load: " + e.message;
      show($("phone-error"));
    }
  }
});
$("phone-modal-close").addEventListener("click", () => hide(phoneModal));
$("phone-cancel").addEventListener("click", () => hide(phoneModal));
$("phone-back").addEventListener("click", () => showPhoneStep(1));
$("phone-send").addEventListener("click", async () => {
  const num = $("phone-number").value.trim();
  if (!/^\+\d{8,15}$/.test(num.replace(/\s+/g, ""))) {
    $("phone-error").textContent = "Use E.164 format with country code, e.g. +919876543210";
    show($("phone-error"));
    return;
  }
  hide($("phone-error"));
  $("phone-send").disabled = true;
  try {
    phoneConfirmation = await signInWithPhoneNumber(auth, num.replace(/\s+/g, ""), phoneVerifier);
    $("phone-display").textContent = num;
    showPhoneStep(2);
  } catch (e) {
    if (e?.code === "auth/operation-not-allowed") {
      $("phone-error").textContent = "Phone sign-in isn't enabled in Firebase Console → Authentication → Sign-in method.";
    } else {
      $("phone-error").textContent = humanise(e);
    }
    show($("phone-error"));
    // recaptcha is single-use; reset
    try { phoneVerifier.clear(); } catch {}
    phoneVerifier = null;
  } finally {
    $("phone-send").disabled = false;
  }
});
$("phone-verify").addEventListener("click", async () => {
  const code = $("phone-code").value.trim();
  if (!/^\d{6}$/.test(code)) {
    $("phone-error").textContent = "Enter the 6-digit code.";
    show($("phone-error"));
    return;
  }
  $("phone-verify").disabled = true;
  try {
    await phoneConfirmation.confirm(code);
    hide(phoneModal);
  } catch (e) {
    $("phone-error").textContent = humanise(e);
    show($("phone-error"));
  } finally {
    $("phone-verify").disabled = false;
  }
});

// Password reset ------------------------------------------------------------
$("reset-link").addEventListener("click", async (ev) => {
  ev.preventDefault();
  const email = $("email").value.trim();
  if (!email) {
    authError.textContent = "Enter your email above first, then click reset.";
    show(authError);
    return;
  }
  try {
    await sendPasswordResetEmail(auth, email);
    toast("Reset email sent to " + email);
  } catch (e) {
    authError.textContent = humanise(e);
    show(authError);
  }
});

// Sign-out / denied self-promote --------------------------------------------
signoutBtn.addEventListener("click", () => signOut(auth));
deniedSignout.addEventListener("click", () => signOut(auth));
$("copy-uid").addEventListener("click", async () => {
  const uid = $("denied-uid").textContent;
  try { await navigator.clipboard.writeText(uid); toast("UID copied"); }
  catch { toast("Copy failed — select and copy manually", "err"); }
});
$("self-promote").addEventListener("click", async () => {
  const uid = auth.currentUser?.uid;
  if (!uid) return;
  const btn = $("self-promote"); btn.disabled = true;
  try {
    // Atomic: grant self super-admin + close the bootstrap window.
    const batch = writeBatch(db);
    batch.set(doc(db, "admins", uid), {
      role: "super",
      grantedBy: "self-bootstrap",
      grantedAt: serverTimestamp(),
    });
    batch.set(doc(db, "bootstrap", "done"), {
      firstAdmin: uid,
      at: serverTimestamp(),
    });
    await batch.commit();
    toast("Promoted to super-admin! Reloading…");
    setTimeout(() => location.reload(), 800);
  } catch (e) {
    btn.disabled = false;
    if (e?.code === "permission-denied") {
      toast("Denied — an admin already exists. Ask them to add you.", "err");
    } else {
      toast("Promote failed: " + e.message, "err");
    }
  }
});

function humanise(e) {
  const code = e?.code || "";
  if (code.includes("invalid-credential") || code.includes("wrong-password")) return "Wrong email or password.";
  if (code.includes("user-not-found")) return "No user with that email — switch to “Create email account” to sign up.";
  if (code.includes("email-already-in-use")) return "That email is already registered. Switch to Sign in.";
  if (code.includes("weak-password")) return "Password must be at least 6 characters.";
  if (code.includes("invalid-email")) return "That doesn't look like a valid email.";
  if (code.includes("too-many-requests")) return "Too many attempts. Try again in a minute.";
  if (code.includes("network-request-failed")) return "Network error — check connection.";
  if (code.includes("invalid-phone-number")) return "Phone number is invalid. Include country code (+91, +1…).";
  if (code.includes("invalid-verification-code")) return "Wrong code. Check the SMS again.";
  if (code.includes("popup-blocked")) return "Popup was blocked — allow popups for this site.";
  return e?.message || String(e);
}

let unsubs = [];
function dispose() { unsubs.forEach((u) => { try { u(); } catch {} }); unsubs = []; }

// Tracks the signed-in user's role: "super" | "sub" | null
let currentRole = null;
function isSuper() { return currentRole === "super"; }
function isSub()   { return currentRole === "sub"; }

onAuthStateChanged(auth, async (user) => {
  dispose();
  currentRole = null;
  if (!user) {
    hide(deniedScreen); hide(adminScreen);
    show(authScreen);
    hide(signoutBtn);
    who.textContent = "";
    return;
  }
  who.textContent = user.email || user.phoneNumber || user.uid;
  // Resolve admin status + role from admins/{uid}
  try {
    const adminDoc = await getDoc(doc(db, "admins", user.uid));
    if (adminDoc.exists()) {
      const d = adminDoc.data() || {};
      // Missing/legacy role → treat as super (back-compat with rules).
      currentRole = (d.role === "sub") ? "sub" : "super";
    }
  } catch (e) {
    console.warn("admin check failed", e);
  }
  if (!currentRole) {
    hide(authScreen); hide(adminScreen);
    show(deniedScreen); show(signoutBtn);
    deniedUid.textContent = user.uid;
    return;
  }
  hide(authScreen); hide(deniedScreen);
  show(adminScreen); show(signoutBtn);

  // Defensive: any super-admin sign-in writes the bootstrap sentinel so the
  // self-promote window can't be reopened. Idempotent: rule blocks update.
  if (isSuper()) {
    try {
      await setDoc(doc(db, "bootstrap", "done"), {
        firstAdmin: user.uid,
        at: serverTimestamp(),
      });
    } catch (_) { /* already exists or no perms — fine */ }
  }

  // Stamp the user's role on the top bar.
  who.textContent = `${user.email || user.phoneNumber || user.uid} · ${currentRole.toUpperCase()}`;

  // Mirror lib/services/auth_service.dart::_touchUserDoc — write users/{uid}
  // so this account shows up in the Users list (and the count tile).
  try {
    await setDoc(doc(db, "users", user.uid), {
      uid: user.uid,
      email: user.email || null,
      displayName: user.displayName || null,
      photoURL: user.photoURL || null,
      phoneNumber: user.phoneNumber || null,
      isAnonymous: user.isAnonymous,
      providers: (user.providerData || []).map((p) => p.providerId),
      lastLoginAt: serverTimestamp(),
      createdAt: serverTimestamp(),
      scansCount: 0,
      adminConsoleLogin: true,
    }, { merge: true });
  } catch (e) {
    console.warn("touch users/{uid} failed:", e);
  }

  bootAdmin();
});

// ---------------------------------------------------------------- Dashboard
async function loadCounts() {
  const targets = {
    "count-users":  collection(db, "users"),
    "count-scans":  collection(db, "scans"),
    "count-ads":    query(collection(db, "ads"), where("enabled", "==", true)),
    "count-admins": collection(db, "admins"),
  };
  for (const [id, q] of Object.entries(targets)) {
    try {
      const s = await getCountFromServer(q);
      $(id).textContent = s.data().count;
    } catch (e) {
      $(id).textContent = "—";
    }
  }
}

// ---------------------------------------------------------------- Ads CRUD
function adFromDoc(d) {
  const data = d.data() || {};
  const t = (v) => v?.toDate ? v.toDate() : null;
  return {
    id: d.id,
    title: data.title || "",
    body: data.body || "",
    imageUrl: data.imageUrl || "",
    ctaLabel: data.ctaLabel || "",
    ctaUrl: data.ctaUrl || "",
    enabled: data.enabled !== false,
    priority: Number(data.priority) || 0,
    startsAt: t(data.startsAt),
    endsAt: t(data.endsAt),
    updatedBy: data.updatedBy || "",
    updatedAt: t(data.updatedAt),
  };
}
function renderAds(ads) {
  const list = $("ads-list");
  const summary = $("ads-summary");
  if (!ads.length) {
    list.innerHTML = `<div class="empty">No ads yet. Tap “New ad” to add the first one — or seed sample ads below.</div>`;
    summary.textContent = "";
    return;
  }
  const liveCount = ads.filter(isLive).length;
  summary.textContent = `${liveCount} live / ${ads.length} total`;
  list.innerHTML = ads.map((a) => {
    const live = isLive(a);
    const stateLabel = live ? "LIVE" : (a.enabled ? "SCHEDULED" : "OFF");
    const stateClass = live ? "pill--live" : (a.enabled ? "pill--scheduled" : "pill--off");
    return `
      <div class="ad-row ${live ? "live" : ""}" data-id="${esc(a.id)}">
        <div class="dot"></div>
        <div>
          <p class="ad-title">${esc(a.title)}</p>
          <p class="ad-body">${esc(a.body)}</p>
          <div class="pills">
            <span class="pill ${stateClass}">${stateLabel}</span>
            <span class="pill pill--priority">P ${a.priority}</span>
            ${a.ctaLabel ? `<span class="pill">CTA</span>` : ""}
            ${a.imageUrl ? `<span class="pill">IMG</span>` : ""}
          </div>
        </div>
        <div class="ad-actions">
          <button class="btn btn--icon" data-act="edit">Edit</button>
          <button class="btn btn--icon btn--danger" data-act="del">Delete</button>
        </div>
      </div>`;
  }).join("");

  // wire actions
  list.querySelectorAll(".ad-row").forEach((row) => {
    const id = row.dataset.id;
    const ad = ads.find((x) => x.id === id);
    row.addEventListener("click", (ev) => {
      const act = ev.target.dataset.act;
      if (act === "del") { deleteAd(ad); return; }
      openAdModal(ad);
    });
  });
}
let _ads = [];
function subscribeAds() {
  const q = query(collection(db, "ads"), orderBy("priority", "desc"), orderBy("updatedAt", "desc"));
  const unsub = onSnapshot(q, (snap) => {
    _ads = snap.docs.map(adFromDoc);
    renderAds(_ads);
    // refresh live-ads count cheaply
    $("count-ads").textContent = _ads.filter((a) => a.enabled).length;
  }, (err) => {
    $("ads-list").innerHTML = `<div class="empty">Couldn't load ads: ${esc(err.message)}</div>`;
  });
  unsubs.push(unsub);
}

async function deleteAd(ad) {
  if (!confirm(`Delete “${ad.title}”? This removes the card for everyone.`)) return;
  try {
    await deleteDoc(doc(db, "ads", ad.id));
    toast("Ad deleted");
  } catch (e) { toast("Delete failed: " + e.message, "err"); }
}

// ---------------------------------------------------------------- Ad modal
const modal = $("ad-modal");
function openAdModal(ad) {
  $("ad-modal-mode").textContent = ad ? "Edit" : "New";
  $("ad-id").value         = ad?.id || "";
  $("ad-title").value      = ad?.title || "";
  $("ad-body").value       = ad?.body || "";
  $("ad-image").value      = ad?.imageUrl || "";
  $("ad-cta-label").value  = ad?.ctaLabel || "";
  $("ad-cta-url").value    = ad?.ctaUrl || "";
  $("ad-priority").value   = ad?.priority ?? 0;
  $("ad-enabled").checked  = ad?.enabled ?? true;
  $("ad-starts-at").value  = ad?.startsAt ? toLocalDT(ad.startsAt) : "";
  $("ad-ends-at").value    = ad?.endsAt   ? toLocalDT(ad.endsAt)   : "";
  show(modal);
}
function closeAdModal() { hide(modal); }
function toLocalDT(d) {
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}
$("new-ad").addEventListener("click", () => openAdModal(null));
$("ad-modal-close").addEventListener("click", closeAdModal);
$("ad-modal-cancel").addEventListener("click", closeAdModal);
modal.addEventListener("click", (e) => { if (e.target === modal) closeAdModal(); });

$("ad-form").addEventListener("submit", async (ev) => {
  ev.preventDefault();
  const uid = auth.currentUser?.uid || "unknown";
  const id = $("ad-id").value;
  const data = {
    title: $("ad-title").value.trim(),
    body:  $("ad-body").value.trim(),
    enabled: $("ad-enabled").checked,
    priority: Number($("ad-priority").value) || 0,
    updatedBy: uid,
    updatedAt: serverTimestamp(),
  };
  const img = $("ad-image").value.trim();
  if (img) data.imageUrl = img;
  const ctaLabel = $("ad-cta-label").value.trim();
  const ctaUrl   = $("ad-cta-url").value.trim();
  if (ctaLabel) data.ctaLabel = ctaLabel;
  if (ctaUrl)   data.ctaUrl   = ctaUrl;
  const sa = $("ad-starts-at").value;
  const ea = $("ad-ends-at").value;
  if (sa) data.startsAt = Timestamp.fromDate(new Date(sa));
  if (ea) data.endsAt   = Timestamp.fromDate(new Date(ea));
  try {
    if (id) {
      await setDoc(doc(db, "ads", id), data, { merge: true });
    } else {
      await addDoc(collection(db, "ads"), data);
    }
    closeAdModal();
    toast(id ? "Ad updated" : "Ad created");
  } catch (e) {
    toast("Save failed: " + e.message, "err");
  }
});

// ---------------------------------------------------------------- Users
function renderUsers(docs) {
  const list = $("users-list");
  if (!docs.length) { list.innerHTML = `<div class="empty">No users yet.</div>`; return; }
  // Sub-admins see read-only role badges; supers get the dropdown.
  const editable = isSuper();
  list.innerHTML = docs.map((d) => {
    const u = d.data() || {};
    const uid = u.uid || d.id;
    const isAnon = u.isAnonymous !== false && !u.email;
    const name = u.email || u.displayName || (isAnon ? "Anonymous" : "Unknown");
    const scans = Number(u.scansCount || 0);
    const last  = u.lastLoginAt?.toDate?.();
    const isMe  = auth.currentUser?.uid === uid;
    const roleControl = editable
      ? `<select class="role-select" data-uid="${esc(uid)}">
           <option value="none">None</option>
           <option value="sub">Sub-admin</option>
           <option value="super">Super-admin</option>
         </select>`
      : `<span class="pill role-badge" data-uid="${esc(uid)}">—</span>`;
    return `
      <div class="user-row" data-uid="${esc(uid)}">
        <div class="avatar ${isAnon ? "anon" : ""}">${isAnon ? "?" : (name[0] || "U").toUpperCase()}</div>
        <div>
          <div class="user-name">${esc(name)} ${isMe ? `<span class="pill pill--priority" style="margin-left:6px">YOU</span>` : ""}</div>
          <div class="user-uid">${esc(uid)}</div>
          <div class="user-meta">
            <span class="pill ${isAnon ? "pill--scheduled" : "pill--live"}">${isAnon ? "ANON" : "REGISTERED"}</span>
            <span class="pill pill--priority">${scans} scans</span>
            ${last ? `<span class="pill">${esc(rel(last))}</span>` : ""}
          </div>
        </div>
        <div class="toggle">${roleControl}</div>
      </div>`;
  }).join("");

  // Live-bind each row's role control to admins/{uid}
  list.querySelectorAll("[data-uid]").forEach((row) => {
    if (!row.classList?.contains("user-row") && !row.classList?.contains("role-select") && !row.classList?.contains("role-badge")) return;
  });

  list.querySelectorAll(".role-select, .role-badge").forEach((el) => {
    const uid = el.dataset.uid;
    const ref = doc(db, "admins", uid);
    const unsub = onSnapshot(ref, (snap) => {
      const role = snap.exists()
        ? ((snap.data().role === "sub") ? "sub" : "super")
        : "none";
      if (el.classList.contains("role-select")) {
        el.value = role;
        el.dataset.current = role;
        el.className = `role-select role-select--${role}`;
      } else {
        const label = role === "none" ? "Not admin" : role.toUpperCase();
        el.textContent = label;
        el.className = `pill role-badge role-badge--${role}`;
      }
    });
    unsubs.push(unsub);
    if (el.classList.contains("role-select")) {
      el.addEventListener("change", async () => {
        const prev = el.dataset.current || "none";
        const want = el.value;
        if (prev === want) return;
        // Confirm self-demote / self-removal.
        if (auth.currentUser?.uid === uid && want !== "super") {
          if (!confirm(`Change your own role from super to ${want}? You may lose access.`)) {
            el.value = prev; return;
          }
        }
        try {
          if (want === "none") {
            await deleteDoc(ref);
          } else {
            await setDoc(ref, {
              role: want,
              grantedBy: auth.currentUser?.uid,
              grantedAt: serverTimestamp(),
            }, { merge: true });
          }
          toast(want === "none" ? "Admin revoked" : `Set to ${want}-admin`);
        } catch (e) {
          el.value = prev;
          toast("Update failed: " + e.message, "err");
        }
      });
    }
  });
}
function subscribeUsers() {
  const q = query(collection(db, "users"), orderBy("lastLoginAt", "desc"), limit(200));
  const unsub = onSnapshot(q, (snap) => {
    renderUsers(snap.docs);
  }, (err) => {
    $("users-list").innerHTML = `<div class="empty">Couldn't load users: ${esc(err.message)}</div>`;
  });
  unsubs.push(unsub);
}

// ---------------------------------------------------------------- Seeder
// Mirrors _kDemoAds in lib/services/demo_seeder.dart so re-runs from either
// platform produce the same docs.
const DEMO_ADS = [
  { id: "welcome-card", title: "🥦 Welcome to FoodFat",
    body: "Scan any packed food and get an instant health verdict — backed by Nutri-Score, NOVA & a curated additive risk list.",
    enabled: true, priority: 10 },
  { id: "health-washing-watch", title: "Spot \"healthy\" marketing tricks",
    body: "Words like \"natural\", \"wholesome\", \"no added sugar\" don't protect you from palm oil, maida or glucose syrup. Search a few in the Store.",
    enabled: true, priority: 8,
    ctaLabel: "See examples", ctaUrl: "https://world.openfoodfacts.org/category/biscuits" },
  { id: "nova-explainer", title: "What is NOVA 4?",
    body: "NOVA 4 = ultra-processed: industrial formulations of refined extracts and additives. The more NOVA 4 you eat, the harder your body works.",
    enabled: true, priority: 6,
    ctaLabel: "Learn the NOVA scale", ctaUrl: "https://world.openfoodfacts.org/nova" },
  { id: "scan-maggi", title: "Try scanning a popular product",
    body: "Pick a packet of Maggi, Lay's or Bourn Vita and see how the four pillars stack up.",
    enabled: true, priority: 4 },
  { id: "sample-promo-disabled", title: "(Demo) Coming soon — Premium tips",
    body: "This card is intentionally disabled so you can see what an off-air ad looks like in the Admin list.",
    enabled: false, priority: 1 },
];
$("seed-ads").addEventListener("click", async () => {
  const btn = $("seed-ads"); btn.disabled = true;
  const status = $("seeder-status"); status.textContent = "Seeding…";
  try {
    const uid = auth.currentUser?.uid || "demo-seeder";
    const batch = writeBatch(db);
    for (const a of DEMO_ADS) {
      const { id, ...rest } = a;
      batch.set(doc(db, "ads", id), {
        ...rest, updatedBy: uid, updatedAt: serverTimestamp(),
      }, { merge: true });
    }
    await batch.commit();
    status.textContent = `Seeded ${DEMO_ADS.length} ads.`;
    toast("Sample ads seeded");
  } catch (e) {
    status.textContent = "Seed failed: " + e.message;
    toast("Seed failed", "err");
  } finally { btn.disabled = false; }
});
$("clear-ads").addEventListener("click", async () => {
  if (!confirm("Wipe ALL ads from Firestore? This is irreversible.")) return;
  const btn = $("clear-ads"); btn.disabled = true;
  const status = $("seeder-status"); status.textContent = "Clearing…";
  try {
    // Iterate the live _ads list (cheaper than re-reading).
    const batch = writeBatch(db);
    for (const a of _ads) batch.delete(doc(db, "ads", a.id));
    await batch.commit();
    status.textContent = `Cleared ${_ads.length} ads.`;
    toast("All ads cleared");
  } catch (e) {
    status.textContent = "Clear failed: " + e.message;
    toast("Clear failed", "err");
  } finally { btn.disabled = false; }
});

// ---------------------------------------------------------------- Boot
function bootAdmin() {
  loadCounts();
  subscribeAds();
  subscribeUsers();
  // Permission gating UI: hide destructive bits from sub-admins.
  document.body.dataset.role = currentRole;
  $("seed-ads").disabled  = !isSuper();
  $("clear-ads").disabled = !isSuper();
  $("new-ad").disabled    = !isAdmin();
  if (!isSuper()) {
    const seederNote = document.querySelector(".seeder .muted.small");
    if (seederNote) seederNote.textContent = "Sub-admins can't seed or clear ads — ask a super-admin.";
  }
}
