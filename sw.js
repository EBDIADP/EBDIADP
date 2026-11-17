// Service worker da EBD: deixa o app instalável e mostra a tela mesmo sem internet.
// Os dados vêm do Supabase e NÃO são guardados aqui (precisam de internet).
const CACHE='ebd-v4';
const BASE=['./','./index.html','./manifest.webmanifest','./icon-192.png','./icon-512.png','./apple-touch-icon.png','./logo-header.png'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(BASE)).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
// Rede primeiro (sempre a versão mais nova do app), mas sem travar: se a rede demorar mais de 2,5 s,
// mostra a cópia guardada na hora e deixa a atualização terminar em segundo plano.
const ESPERA=2500;
self.addEventListener('fetch',e=>{
  const r=e.request,u=new URL(r.url);
  if(r.method!=='GET'||u.origin!==location.origin)return;   // nunca interfere no Supabase
  e.respondWith((async()=>{
    // só guarda respostas com sucesso (evita cachear 404/500)
    const rede=fetch(r).then(res=>{if(res.ok){const cp=res.clone();caches.open(CACHE).then(c=>c.put(r,cp))}return res});
    // sem internet ou rede lenta: usa o cache; a tela inicial só substitui NAVEGAÇÕES, nunca .js/.css/imagens
    const cache=()=>caches.match(r).then(m=>m||(r.mode==='navigate'?caches.match('./index.html'):null));
    try{
      return await Promise.race([rede,new Promise((_,no)=>setTimeout(()=>no(new Error('lenta')),ESPERA))]);
    }catch(err){
      const m=await cache();
      if(m){e.waitUntil(rede.catch(()=>{}));return m}
      try{return await rede}catch(x){return Response.error()}
    }
  })());
});
