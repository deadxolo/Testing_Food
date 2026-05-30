// Stories & Recipes — reader contributions.
// Auth + Firestore via the same Firebase project the admin uses.

import { initializeApp } from "https://www.gstatic.com/firebasejs/10.13.2/firebase-app.js";
import {
  getAuth, onAuthStateChanged, signOut,
} from "https://www.gstatic.com/firebasejs/10.13.2/firebase-auth.js";
import {
  getFirestore, collection, doc, getDoc, setDoc, deleteDoc, addDoc,
  onSnapshot, query, where, orderBy, limit, serverTimestamp,
} from "https://www.gstatic.com/firebasejs/10.13.2/firebase-firestore.js";

// Same public Firebase config as the admin console.
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

const $  = (id) => document.getElementById(id);
const $$ = (sel) => Array.from(document.querySelectorAll(sel));

function show(el){ el.hidden = false; }
function hide(el){ el.hidden = true; }
function esc(s){
  return (s ?? "").toString().replace(/[&<>"']/g, (c)=>({
    "&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#39;"
  }[c]));
}
function toast(msg, kind="ok"){
  const t = $("toast"); t.textContent = msg;
  t.style.background = kind === "err" ? "var(--bad)" : "var(--ink)";
  show(t); clearTimeout(toast._t);
  toast._t = setTimeout(()=> hide(t), 2400);
}
function rel(date){
  if (!date) return "";
  const diff = (Date.now() - date.getTime()) / 1000;
  if (diff < 60)    return "just now";
  if (diff < 3600)  return `${Math.floor(diff/60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff/3600)}h ago`;
  if (diff < 604800) return `${Math.floor(diff/86400)}d ago`;
  return `${Math.floor(diff/604800)}w ago`;
}

// ---------------------------------------------------------------- State
let currentUser = null;
let isAdmin = false;
let editingId = null;
let activeFilter = "all";
let unsubAll = null;
let unsubMine = null;
let unsubFeatured = null;

// ---------------------------------------------------------------- Auth state
onAuthStateChanged(auth, async (user) => {
  currentUser = user;
  isAdmin = false;
  if (user) {
    try {
      const ad = await getDoc(doc(db, "admins", user.uid));
      isAdmin = ad.exists();
    } catch {}
    $("who-pill").innerHTML =
      `${esc(user.email || user.phoneNumber || user.uid.slice(0,8))}` +
      (isAdmin ? ` <span class="admin-badge">Admin</span>` : "") +
      ` · <a href="#" id="signout-link">Sign out</a>`;
    $("signout-link").addEventListener("click", (e) => { e.preventDefault(); signOut(auth); });
    hide($("signed-out-cta"));
    show($("compose-form"));
    show($("mine"));
    subscribeMine(user.uid);
    // Update wording in compose
    $("compose-blurb").textContent =
      "Hi " + (user.displayName || user.email || "reader") + " — what do you want to share?";
  } else {
    $("who-pill").innerHTML = `<a href="/admin/">Sign in →</a>`;
    show($("signed-out-cta"));
    hide($("compose-form"));
    hide($("mine"));
    if (unsubMine) { unsubMine(); unsubMine = null; }
    $("compose-blurb").textContent = "Sign in to post a story or recipe. Same account as the rest of FoodFat — pick any method.";
  }
});

// ---------------------------------------------------------------- Helpers
function storyFromDoc(d) {
  const data = d.data() || {};
  const t = (v) => v?.toDate ? v.toDate() : null;
  return {
    id: d.id,
    uid: data.uid || "",
    authorName: data.authorName || "Anonymous reader",
    authorEmail: data.authorEmail || "",
    authorPhotoURL: data.authorPhotoURL || "",
    type: data.type === "recipe" ? "recipe" : "story",
    title: data.title || "",
    body:  data.body  || "",
    imageUrl: data.imageUrl || "",
    ingredients: Array.isArray(data.ingredients) ? data.ingredients : [],
    steps:       Array.isArray(data.steps)       ? data.steps       : [],
    tags:        Array.isArray(data.tags)        ? data.tags        : [],
    featured: data.featured === true,
    published: data.published !== false,
    createdAt: t(data.createdAt),
    updatedAt: t(data.updatedAt),
  };
}

function renderCard(s, opts = {}) {
  const isMine = currentUser?.uid === s.uid;
  const canEdit = isMine || isAdmin;
  const ingredientsBlock = s.type === "recipe" && s.ingredients.length
    ? `<div class="ingredients"><strong>Ingredients</strong><ul>${
        s.ingredients.map((i)=>`<li>${esc(i)}</li>`).join("")
      }</ul></div>` : "";
  const stepsBlock = s.type === "recipe" && s.steps.length
    ? `<div class="steps"><strong>Steps</strong><ol>${
        s.steps.map((i)=>`<li>${esc(i)}</li>`).join("")
      }</ol></div>` : "";
  const adminActions = isAdmin ? `
    <button class="btn btn--icon" data-act="feature">${s.featured ? "★ Unfeature" : "☆ Feature"}</button>
    <button class="btn btn--icon" data-act="toggle-pub">${s.published ? "Hide" : "Unhide"}</button>
  ` : "";
  const ownerActions = canEdit ? `
    <button class="btn btn--icon" data-act="edit">Edit</button>
    <button class="btn btn--icon btn--danger" data-act="delete">Delete</button>
  ` : "";
  const actions = (adminActions + ownerActions).trim();

  return `
    <article class="story-card type-${s.type} ${s.published ? "" : "is-hidden"}" data-id="${esc(s.id)}">
      <div class="story-card__head">
        <span class="story-card__type">${s.type === "recipe" ? "🥗 Recipe" : "📝 Story"}</span>
        ${s.featured ? `<span class="story-card__featured">Featured</span>` : ""}
      </div>
      ${s.imageUrl ? `<img class="story-card__image" src="${esc(s.imageUrl)}" alt="" loading="lazy" onerror="this.style.display='none'"/>` : ""}
      <h4>${esc(s.title)}</h4>
      <p class="story-card__body">${esc(s.body)}</p>
      ${ingredientsBlock}
      ${stepsBlock}
      ${s.tags.length ? `<div class="tags">${s.tags.map((t)=>`<span class="tag">${esc(t)}</span>`).join("")}</div>` : ""}
      <div class="story-card__meta">
        <span class="story-card__author">${esc(s.authorName)}</span>
        ${s.createdAt ? `<span>${esc(rel(s.createdAt))}</span>` : ""}
        ${!s.published ? `<span class="tag" style="background:rgba(211,47,47,0.12);color:var(--bad)">HIDDEN</span>` : ""}
      </div>
      ${actions ? `<div class="story-card__actions">${actions}</div>` : ""}
    </article>
  `;
}

function bindCardActions(container, getStoryById) {
  container.querySelectorAll(".story-card").forEach((card) => {
    const id = card.dataset.id;
    card.querySelectorAll("[data-act]").forEach((btn) => {
      btn.addEventListener("click", async (ev) => {
        ev.stopPropagation();
        const s = getStoryById(id);
        if (!s) return;
        const act = btn.dataset.act;
        try {
          if (act === "feature") {
            await setDoc(doc(db, "stories", id), { featured: !s.featured, moderatedAt: serverTimestamp(), moderatedBy: currentUser.uid }, { merge: true });
            toast(s.featured ? "Unfeatured" : "Featured");
          } else if (act === "toggle-pub") {
            await setDoc(doc(db, "stories", id), { published: !s.published, moderatedAt: serverTimestamp(), moderatedBy: currentUser.uid }, { merge: true });
            toast(s.published ? "Hidden" : "Restored");
          } else if (act === "edit") {
            openEdit(s);
          } else if (act === "delete") {
            if (!confirm(`Delete “${s.title}”?`)) return;
            await deleteDoc(doc(db, "stories", id));
            toast("Deleted");
          }
        } catch (e) { toast("Action failed: " + e.message, "err"); }
      });
    });
  });
}

// ---------------------------------------------------------------- Subscriptions
let allStories = [];
function subscribeAll() {
  const q = query(
    collection(db, "stories"),
    where("published", "==", true),
    orderBy("createdAt", "desc"),
    limit(200)
  );
  unsubAll = onSnapshot(q, (snap) => {
    allStories = snap.docs.map(storyFromDoc);
    renderFeed();
    renderFeatured();
  }, (err) => {
    $("feed").innerHTML = `<div class="empty">Couldn't load posts: ${esc(err.message)}<br/><span class="muted small">If this is the first run, deploy the new Firestore rules + composite index.</span></div>`;
  });
}

let myStories = [];
function subscribeMine(uid) {
  if (unsubMine) unsubMine();
  const q = query(
    collection(db, "stories"),
    where("uid", "==", uid),
    orderBy("createdAt", "desc")
  );
  unsubMine = onSnapshot(q, (snap) => {
    myStories = snap.docs.map(storyFromDoc);
    renderMine();
  });
}

function renderFeed() {
  const feed = $("feed");
  const filtered = activeFilter === "all"
    ? allStories
    : allStories.filter((s) => s.type === activeFilter);
  if (!filtered.length) {
    feed.innerHTML = "";
    show($("feed-empty"));
    return;
  }
  hide($("feed-empty"));
  feed.innerHTML = filtered.map((s) => renderCard(s)).join("");
  bindCardActions(feed, (id) => allStories.find((s) => s.id === id));
}

function renderMine() {
  const list = $("mine-list");
  if (!myStories.length) {
    list.innerHTML = "";
    show($("mine-empty"));
    return;
  }
  hide($("mine-empty"));
  list.innerHTML = myStories.map((s) => renderCard(s)).join("");
  bindCardActions(list, (id) => myStories.find((s) => s.id === id));
}

function renderFeatured() {
  const featured = allStories.find((s) => s.featured) || allStories[0];
  const slot = $("featured-card");
  if (!featured) {
    slot.innerHTML = `<p class="kicker">Nothing featured yet</p><p style="font-style:italic;color:var(--ink-soft)">Be the first to post — admins will star their pick of the issue.</p>`;
    return;
  }
  slot.innerHTML = `
    <p class="kicker">${featured.featured ? "Editor's Pick" : "Most recent"}</p>
    <h4>${esc(featured.title)}</h4>
    <p style="font-family:var(--serif);font-size:16.5px;line-height:1.55;margin:8px 0 12px">${esc(featured.body).slice(0, 280)}${featured.body.length > 280 ? "…" : ""}</p>
    <p class="muted small">— ${esc(featured.authorName)} · ${esc(rel(featured.createdAt))}</p>
  `;
}

// ---------------------------------------------------------------- Compose
const form = $("compose-form");
const typeRadios = () => $$('input[name="type"]');
function updateTypeUI() {
  const t = typeRadios().find((r) => r.checked)?.value || "story";
  document.querySelectorAll(".recipe-only").forEach((el) => el.hidden = (t !== "recipe"));
}
typeRadios().forEach((r) => r.addEventListener("change", updateTypeUI));
updateTypeUI();

function openEdit(s) {
  editingId = s.id;
  $("story-id").value = s.id;
  $("story-title").value = s.title;
  $("story-body").value = s.body;
  $("story-image").value = s.imageUrl;
  $("story-ingredients").value = s.ingredients.join("\n");
  $("story-steps").value = s.steps.join("\n");
  $("story-tags").value = s.tags.join(", ");
  const radio = typeRadios().find((r) => r.value === s.type);
  if (radio) radio.checked = true;
  updateTypeUI();
  $("compose-title").textContent = "Edit your post";
  $("compose-submit").textContent = "Save changes";
  show($("cancel-edit"));
  document.getElementById("compose").scrollIntoView({ behavior: "smooth" });
}
$("cancel-edit").addEventListener("click", () => {
  editingId = null;
  form.reset();
  $("story-id").value = "";
  updateTypeUI();
  $("compose-title").textContent = "Tell the readers what worked";
  $("compose-submit").textContent = "Publish";
  hide($("cancel-edit"));
});

form.addEventListener("submit", async (ev) => {
  ev.preventDefault();
  hide($("compose-error"));
  if (!currentUser) { toast("Sign in first", "err"); return; }

  const type = typeRadios().find((r) => r.checked)?.value || "story";
  const title = $("story-title").value.trim();
  const body = $("story-body").value.trim();
  if (!title || !body) {
    $("compose-error").textContent = "Title and body are required.";
    show($("compose-error")); return;
  }

  const tags = $("story-tags").value
    .split(",").map((t) => t.trim().toLowerCase()).filter(Boolean).slice(0, 5);

  const ingredients = $("story-ingredients").value
    .split("\n").map((l) => l.trim()).filter(Boolean);
  const steps = $("story-steps").value
    .split("\n").map((l) => l.trim()).filter(Boolean);
  const imageUrl = $("story-image").value.trim();

  const payload = {
    uid: currentUser.uid,
    authorName: currentUser.displayName || currentUser.email || "Reader",
    authorEmail: currentUser.email || null,
    authorPhotoURL: currentUser.photoURL || null,
    type,
    title,
    body,
    imageUrl: imageUrl || null,
    ingredients: type === "recipe" ? ingredients : [],
    steps:       type === "recipe" ? steps       : [],
    tags,
    published: true,
    updatedAt: serverTimestamp(),
  };

  $("compose-submit").disabled = true;
  $("compose-status").textContent = editingId ? "Saving…" : "Publishing…";
  try {
    if (editingId) {
      await setDoc(doc(db, "stories", editingId), payload, { merge: true });
      toast("Saved");
    } else {
      payload.createdAt = serverTimestamp();
      payload.featured = false;
      await addDoc(collection(db, "stories"), payload);
      toast("Published");
    }
    form.reset();
    $("story-id").value = "";
    editingId = null;
    updateTypeUI();
    $("compose-title").textContent = "Tell the readers what worked";
    $("compose-submit").textContent = "Publish";
    hide($("cancel-edit"));
    $("compose-status").textContent = "";
  } catch (e) {
    $("compose-error").textContent = "Save failed: " + e.message;
    show($("compose-error"));
    $("compose-status").textContent = "";
  } finally {
    $("compose-submit").disabled = false;
  }
});

// Filter chips
document.querySelectorAll(".filter-row .chip").forEach((c) => {
  c.addEventListener("click", () => {
    document.querySelectorAll(".filter-row .chip").forEach((x) => x.classList.remove("is-active"));
    c.classList.add("is-active");
    activeFilter = c.dataset.filter;
    renderFeed();
  });
});

// "Share yours" anchor: scroll + focus title
$("open-compose-top").addEventListener("click", () => {
  setTimeout(() => {
    if (currentUser) $("story-title").focus();
  }, 250);
});

// Kick off the public feed
subscribeAll();
