/* ChipZett app: opens without a connection. Pages come from the network when there is one (so updates arrive at once)
   and from the last saved copy when there is not. Fonts are kept after their first load. Nothing else is touched. */
const C='chipzett-app-v1';
self.addEventListener('install',e=>{self.skipWaiting();e.waitUntil(caches.open(C).then(c=>c.addAll(['./','manifest.webmanifest','icon-192.png','icon-512.png']).catch(()=>{})))});
self.addEventListener('activate',e=>e.waitUntil((async()=>{for(const k of await caches.keys())if(k!==C&&k.startsWith('chipzett-app-'))await caches.delete(k);await self.clients.claim()})()));
self.addEventListener('fetch',e=>{const r=e.request;if(r.method!=='GET')return;const u=new URL(r.url),font=u.hostname==='fonts.googleapis.com'||u.hostname==='fonts.gstatic.com';
  if(u.origin!==location.origin&&!font)return;
  if(font){e.respondWith(caches.open(C).then(async c=>{const hit=await c.match(r);if(hit)return hit;const res=await fetch(r);if(res.ok||res.type==='opaque')try{await c.put(r,res.clone())}catch(x){}return res}));return}
  e.respondWith((async()=>{const c=await caches.open(C);try{const res=await fetch(r);if(res.ok)try{await c.put(r,res.clone())}catch(x){}return res}
    catch(err){return(await c.match(r,{ignoreSearch:true}))||(r.mode==='navigate'?(await c.match('./'))||Response.error():Response.error())}})())});
