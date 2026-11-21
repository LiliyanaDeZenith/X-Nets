-- X'Nest: tempel semua di Supabase > SQL Editor, lalu Run (aman dijalankan ulang)
create table if not exists public.profiles(
  id uuid primary key references auth.users on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_.]{3,20}$'),
  display text, bio text default '', avatar text, banner jsonb,
  verified_until timestamptz, role text not null default 'user',
  banned boolean not null default false,
  s jsonb not null default '{"theme":"auto","size":"n","autoplay":0,"dm":"all"}',
  created_at timestamptz not null default now());
create table if not exists public.strikes(
  user_id uuid primary key references public.profiles on delete cascade, n int not null default 0);
create table if not exists public.posts(
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles on delete cascade,
  body text not null default '', media jsonb, created_at timestamptz not null default now());
create table if not exists public.likes(
  post_id bigint references public.posts on delete cascade,
  user_id uuid references public.profiles on delete cascade, primary key(post_id,user_id));
create table if not exists public.comments(
  id bigint generated always as identity primary key,
  post_id bigint not null references public.posts on delete cascade,
  user_id uuid not null references public.profiles on delete cascade,
  body text not null, created_at timestamptz not null default now());
create table if not exists public.rooms(
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('ch','com')), name text not null, descr text default '',
  owner uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now());
create table if not exists public.room_members(
  room_id uuid references public.rooms on delete cascade,
  user_id uuid references public.profiles on delete cascade, primary key(room_id,user_id));
create table if not exists public.messages(
  id bigint generated always as identity primary key, room text not null,
  user_id uuid not null references public.profiles on delete cascade, body text not null,
  announce boolean not null default false, created_at timestamptz not null default now());
alter table public.rooms add column if not exists avatar text;
create table if not exists public.follows(
  follower uuid references public.profiles on delete cascade,
  following uuid references public.profiles on delete cascade,
  created_at timestamptz not null default now(),
  primary key(follower,following), check (follower<>following));
create index if not exists messages_room on public.messages(room, created_at);
create index if not exists posts_time on public.posts(created_at desc);
create table if not exists public.site(id int primary key, text text, banner jsonb);
create table if not exists public.words(word text primary key check (word ~ '^[a-z0-9]{1,30}$'));
insert into public.site(id,text) values(1,'Selamat datang di X''Nest') on conflict do nothing;
insert into public.words(word) values ('anjing'),('bangsat'),('kontol'),('memek'),('ngentot'),('bajingan'),('goblok'),('tolol'),('babi'),('asu'),('fuck'),('shit'),('bitch'),('asshole') on conflict do nothing;

create or replace function public.is_dev() returns boolean language sql stable security definer set search_path=public as
$$ select exists(select 1 from profiles where id=auth.uid() and role='dev') $$;
create or replace function public.is_banned() returns boolean language sql stable security definer set search_path=public as
$$ select coalesce((select banned from profiles where id=auth.uid()),false) $$;
create or replace function public.username_free(u text) returns boolean language sql stable security definer set search_path=public as
$$ select not exists(select 1 from profiles where username=lower(u)) $$;
create or replace function public.can_read(r text) returns boolean language sql stable security definer set search_path=public as
$$ select auth.uid() is not null and (r='global'
   or (r like 'dm:%' and auth.uid()::text = any(string_to_array(substr(r,4),'~')))
   or exists(select 1 from rooms where id::text=r)) $$;
create or replace function public.can_post(r text) returns boolean language plpgsql stable security definer set search_path=public as $$
declare me uuid := auth.uid(); ids text[]; tp profiles; mp profiles; rm rooms;
begin
  if me is null or is_banned() then return false; end if;
  if r='global' then return true; end if;
  if r like 'dm:%' then
    ids := string_to_array(substr(r,4),'~');
    if array_length(ids,1)<>2 or not (me::text = any(ids)) then return false; end if;
    select * into tp from profiles where id::text = (select x from unnest(ids) x where x<>me::text limit 1);
    if tp.id is null or tp.banned then return false; end if;
    if tp.role<>'dev' and tp.s->>'dm'='verified' then
      select * into mp from profiles where id=me;
      return mp.role='dev' or coalesce(mp.verified_until>now(),false);
    end if;
    return true;
  end if;
  select * into rm from rooms where id::text=r;
  if rm.id is null then return false; end if;
  if rm.type='ch' then return rm.owner=me or is_dev() or public.room_owner(rm.id); end if;
  return exists(select 1 from room_members where room_id=rm.id and user_id=me);
end $$;

create or replace function public.censor(t text) returns text language plpgsql stable set search_path=public as $$
declare p text;
begin
  select string_agg(word,'|') into p from words;
  if p is null or t is null then return t; end if;
  return regexp_replace(t,'\m('||p||')\M','****','gi');
end $$;
create or replace function public.t_clean() returns trigger language plpgsql security definer set search_path=public as $$
declare c text;
begin
  c := censor(new.body);
  if c is distinct from new.body then
    insert into strikes(user_id,n) values(new.user_id,1) on conflict(user_id) do update set n=strikes.n+1;
    new.body := c;
  end if;
  return new;
end $$;
create or replace function public.t_clean2() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_table_name='profiles' then new.display:=censor(new.display); new.bio:=censor(new.bio);
  else new.name:=censor(new.name); new.descr:=censor(new.descr); end if;
  return new;
end $$;
create or replace function public.t_room() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='INSERT' then insert into room_members(room_id,user_id) values(new.id,new.owner); return new;
  else delete from messages where room=old.id::text; return old; end if;
end $$;
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare u text; dv boolean;
begin
  u := lower(coalesce(new.raw_user_meta_data->>'username',''));
  dv := lower(new.email)='websitescarlett@gmail.com';
  if u !~ '^[a-z0-9_.]{3,20}$' then raise exception 'Username tidak valid'; end if;
  if u in ('devweb','admin') and not dv then raise exception 'Username dipakai'; end if;
  insert into profiles(id,username,display,role) values(new.id,u,u,case when dv then 'dev' else 'user' end);
  return new;
end $$;
do $$ declare t text; begin
  foreach t in array array['posts','comments','messages'] loop
    execute format('drop trigger if exists clean on public.%I',t);
    execute format('create trigger clean before insert on public.%I for each row execute function public.t_clean()',t);
  end loop;
  foreach t in array array['profiles','rooms'] loop
    execute format('drop trigger if exists clean2 on public.%I',t);
    execute format('create trigger clean2 before insert or update on public.%I for each row execute function public.t_clean2()',t);
  end loop;
end $$;
drop trigger if exists room_ins on public.rooms;
create trigger room_ins after insert on public.rooms for each row execute function public.t_room();
drop trigger if exists room_del on public.rooms;
create trigger room_del after delete on public.rooms for each row execute function public.t_room();
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public._purge(uid uuid) returns void language plpgsql security definer set search_path=public as $$
begin
  delete from messages where room in (select id::text from rooms where owner=uid) or (room like 'dm:%' and position(uid::text in room)>0);
  delete from auth.users where id=uid;
end $$;
create or replace function public.delete_me() returns void language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null or is_dev() then raise exception 'Tidak diizinkan'; end if;
  perform _purge(auth.uid());
end $$;
create or replace function public.dev_delete(uid uuid) returns void language plpgsql security definer set search_path=public as $$
begin
  if not is_dev() then raise exception 'Khusus developer'; end if;
  if exists(select 1 from profiles where id=uid and role='dev') then raise exception 'Akun developer tidak bisa dihapus'; end if;
  perform _purge(uid);
end $$;
create or replace function public.dev_ban(uid uuid) returns void language plpgsql security definer set search_path=public as $$
declare b boolean;
begin
  if not is_dev() then raise exception 'Khusus developer'; end if;
  update profiles set banned=not banned where id=uid and role<>'dev' returning banned into b;
  if b is not null then update auth.users set banned_until=case when b then 'infinity'::timestamptz else null end where id=uid; end if;
end $$;
create or replace function public.dev_verify(uid uuid, months int) returns void language plpgsql security definer set search_path=public as $$
begin
  if not is_dev() then raise exception 'Khusus developer'; end if;
  update profiles set verified_until=case when months<0 then null
    else greatest(coalesce(verified_until,now()),now()) + months*interval '1 month' end where id=uid;
end $$;
create or replace function public.dev_users() returns table(id uuid, email text, viol int) language sql stable security definer set search_path=public as $$
  select u.id, u.email::text, coalesce(s.n,0) from auth.users u left join strikes s on s.user_id=u.id where is_dev() $$;

-- Update: pemilik tambahan saluran/komunitas
alter table public.room_members add column if not exists is_owner boolean not null default false;
create or replace function public.room_owner(rid uuid) returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from rooms r where r.id=rid and r.owner=auth.uid()) or exists(select 1 from room_members m where m.room_id=rid and m.user_id=auth.uid() and m.is_owner) $$;

create or replace function public._pol(t text, n text, c text, u text, w text) returns void language plpgsql as $$
begin
  execute format('alter table public.%I enable row level security', t);
  execute format('drop policy if exists %I on public.%I', n, t);
  execute format('create policy %I on public.%I for %s to authenticated %s %s', n, t, c,
    case when u is null then '' else 'using ('||u||')' end,
    case when w is null then '' else 'with check ('||w||')' end);
end $$;
select public._pol('profiles','p_sel','select','true',null);
select public._pol('profiles','p_upd','update','id=auth.uid()','id=auth.uid()');
select public._pol('strikes','p_sel','select','public.is_dev()',null);
select public._pol('posts','p_sel','select','true',null);
select public._pol('posts','p_ins','insert',null,'user_id=auth.uid() and not public.is_banned()');
select public._pol('posts','p_del','delete','user_id=auth.uid() or public.is_dev()',null);
select public._pol('likes','p_sel','select','true',null);
select public._pol('likes','p_ins','insert',null,'user_id=auth.uid() and not public.is_banned()');
select public._pol('likes','p_del','delete','user_id=auth.uid()',null);
select public._pol('comments','p_sel','select','true',null);
select public._pol('comments','p_ins','insert',null,'user_id=auth.uid() and not public.is_banned()');
select public._pol('comments','p_del','delete','user_id=auth.uid() or public.is_dev()',null);
select public._pol('rooms','p_sel','select','true',null);
select public._pol('rooms','p_ins','insert',null,'owner=auth.uid() and not public.is_banned()');
select public._pol('rooms','p_del','delete','owner=auth.uid() or public.is_dev()',null);
select public._pol('rooms','p_upd','update','public.room_owner(id) or public.is_dev()','public.room_owner(id) or public.is_dev()');
select public._pol('follows','p_sel','select','true',null);
select public._pol('follows','p_ins','insert',null,'follower=auth.uid() and not public.is_banned()');
select public._pol('follows','p_del','delete','follower=auth.uid()',null);
select public._pol('room_members','p_sel','select','true',null);
select public._pol('room_members','p_ins','insert',null,'user_id=auth.uid() and not public.is_banned()');
select public._pol('room_members','p_del','delete','user_id=auth.uid() and not exists(select 1 from public.rooms r where r.id=room_id and r.owner=auth.uid())',null);
select public._pol('messages','p_sel','select','public.can_read(room)',null);
select public._pol('messages','p_ins','insert',null,'user_id=auth.uid() and public.can_post(room) and (not announce or public.is_dev())');
select public._pol('messages','p_del','delete','public.is_dev() and public.can_read(room)',null);
select public._pol('site','p_sel','select','true',null);
select public._pol('site','p_upd','update','public.is_dev()','public.is_dev()');
select public._pol('words','p_sel','select','true',null);
select public._pol('words','p_ins','insert',null,'public.is_dev()');
select public._pol('words','p_del','delete','public.is_dev()',null);
drop function public._pol(text,text,text,text,text);

grant usage on schema public to anon, authenticated;
grant select,insert,update,delete on all tables in schema public to authenticated;
grant usage,select on all sequences in schema public to authenticated;
grant execute on all functions in schema public to anon, authenticated;
revoke update on public.profiles from authenticated;
revoke insert,delete on public.profiles from authenticated;
grant update(display,bio,avatar,banner,s) on public.profiles to authenticated;
revoke update on public.rooms from authenticated;
grant update(name,descr,avatar) on public.rooms to authenticated;
revoke execute on function public._purge(uuid) from public, anon, authenticated;

insert into storage.buckets(id,name,public,file_size_limit) values('media','media',true,null)
  on conflict(id) do update set public=true, file_size_limit=null;
drop policy if exists "media upload" on storage.objects;
create policy "media upload" on storage.objects for insert to authenticated
  with check (bucket_id='media' and (storage.foldername(name))[1]=auth.uid()::text);
do $$ declare t text; begin
  foreach t in array array['messages','posts','likes','comments','rooms','room_members','profiles','site','words','follows'] loop
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
      execute format('alter publication supabase_realtime add table public.%I',t);
    end if;
  end loop;
end $$;
insert into public.profiles(id,username,display,role)
select id,'user'||substr(replace(id::text,'-',''),1,8),'user'||substr(replace(id::text,'-',''),1,8),
  case when lower(email)='websitescarlett@gmail.com' then 'dev' else 'user' end
from auth.users u where not exists(select 1 from public.profiles p where p.id=u.id);
-- Tambahan: Mora, beli centang, sandi terlarang (jalankan sekali di SQL Editor, aman diulang)
create table if not exists public.wallets(
  user_id uuid primary key references public.profiles on delete cascade,
  mora int not null default 0, last_claim timestamptz);
create table if not exists public.banned_pw(pw text primary key check (length(pw) between 1 and 100));
create or replace function public.t_wallet() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into wallets(user_id) values(new.id) on conflict do nothing; return new; end $$;
drop trigger if exists wallet_ins on public.profiles;
create trigger wallet_ins after insert on public.profiles for each row execute function public.t_wallet();
insert into public.wallets(user_id) select id from public.profiles on conflict do nothing;

create or replace function public.claim_mora() returns int language plpgsql security definer set search_path=public as $$
declare m int; l timestamptz;
begin
  if auth.uid() is null or is_banned() then raise exception 'Tidak diizinkan'; end if;
  if is_dev() then raise exception 'Developer memiliki Mora tak terbatas'; end if;
  insert into wallets(user_id) values(auth.uid()) on conflict do nothing;
  select last_claim into l from wallets where user_id=auth.uid() for update;
  if l is not null and l > now() - interval '7 days' then
    raise exception 'Klaim berikutnya tersedia pada %', to_char(l + interval '7 days','DD-MM-YYYY HH24:MI'); end if;
  update wallets set mora=mora+100, last_claim=now() where user_id=auth.uid() returning mora into m;
  return m;
end $$;
create or replace function public.buy_check(plan int) returns int language plpgsql security definer set search_path=public as $$
declare cost int; d int; m int;
begin
  if auth.uid() is null or is_banned() then raise exception 'Tidak diizinkan'; end if;
  select c, dd into cost, d from (values (0,100,7),(1,500,30),(2,2500,150),(3,6000,365)) v(i,c,dd) where i=plan;
  if cost is null then raise exception 'Paket tidak valid'; end if;
  if not is_dev() then
    insert into wallets(user_id) values(auth.uid()) on conflict do nothing;
    update wallets set mora=mora-cost where user_id=auth.uid() and mora>=cost returning mora into m;
    if m is null then raise exception 'Mora tidak cukup'; end if;
  end if;
  update profiles set verified_until=greatest(coalesce(verified_until,now()),now())+d*interval '1 day' where id=auth.uid();
  return coalesce(m,0);
end $$;
create or replace function public.pw_allowed(p text) returns boolean language sql stable security definer set search_path=public as
$$ select not exists(select 1 from banned_pw where lower(pw)=lower(p)) $$;
create or replace function public.pw_violation() returns boolean language sql stable security definer set search_path=public,extensions as
$$ select exists(select 1 from auth.users u, banned_pw b where u.id=auth.uid() and u.encrypted_password<>'' and u.encrypted_password=crypt(b.pw,u.encrypted_password)) $$;
create or replace function public.dev_pw_check(uid uuid) returns boolean language sql stable security definer set search_path=public,extensions as
$$ select public.is_dev() and exists(select 1 from auth.users u, banned_pw b where u.id=uid and u.encrypted_password<>'' and u.encrypted_password=crypt(b.pw,u.encrypted_password)) $$;

alter table public.wallets enable row level security;
alter table public.banned_pw enable row level security;
drop policy if exists p_sel on public.wallets;
create policy p_sel on public.wallets for select to authenticated using (user_id=auth.uid() or public.is_dev());
drop policy if exists p_sel on public.banned_pw;
create policy p_sel on public.banned_pw for select to authenticated using (public.is_dev());
drop policy if exists p_ins on public.banned_pw;
create policy p_ins on public.banned_pw for insert to authenticated with check (public.is_dev());
drop policy if exists p_del on public.banned_pw;
create policy p_del on public.banned_pw for delete to authenticated using (public.is_dev());
revoke insert,update,delete on public.wallets from authenticated;
grant select on public.wallets to authenticated;
grant select,insert,delete on public.banned_pw to authenticated;
grant execute on function public.claim_mora(), public.buy_check(int), public.pw_allowed(text), public.pw_violation(), public.dev_pw_check(uuid) to anon, authenticated;

-- ===================== UPDATE (aman dijalankan ulang) =====================
-- Keamanan: kolom is_owner tidak bisa diisi dari klien
revoke insert,update on public.room_members from authenticated;
grant insert(room_id,user_id) on public.room_members to authenticated;
grant execute on function public.room_owner(uuid) to anon, authenticated;

-- Saluran/komunitas: tambah anggota, tambah pemilik, transfer kepemilikan
create or replace function public.room_add(rid uuid,uname text,mk_owner boolean default false) returns void language plpgsql security definer set search_path=public as $$
declare t uuid;
begin
  if not (public.room_owner(rid) or is_dev()) then raise exception 'Hanya pemilik'; end if;
  select id into t from profiles where username=lower(trim(uname));
  if t is null then raise exception 'Pengguna tidak ditemukan'; end if;
  insert into room_members(room_id,user_id,is_owner) values(rid,t,mk_owner) on conflict(room_id,user_id) do update set is_owner=room_members.is_owner or excluded.is_owner;
end $$;
create or replace function public.room_transfer(rid uuid,uname text) returns void language plpgsql security definer set search_path=public as $$
declare t uuid;
begin
  if not (exists(select 1 from rooms where id=rid and owner=auth.uid()) or is_dev()) then raise exception 'Hanya pemilik utama'; end if;
  select id into t from profiles where username=lower(trim(uname));
  if t is null then raise exception 'Pengguna tidak ditemukan'; end if;
  insert into room_members(room_id,user_id,is_owner) values(rid,t,true) on conflict(room_id,user_id) do update set is_owner=true;
  update rooms set owner=t where id=rid;
end $$;

-- Top up Mora oleh dev (username + Gmail + jumlah)
create table if not exists public.topups(id bigint generated always as identity primary key,user_id uuid references public.profiles on delete cascade,mora int not null,by_dev uuid,created_at timestamptz not null default now());
alter table public.topups enable row level security;
drop policy if exists p_sel on public.topups;
create policy p_sel on public.topups for select to authenticated using (user_id=auth.uid() or public.is_dev());
revoke insert,update,delete on public.topups from authenticated;
grant select on public.topups to authenticated;
create or replace function public.dev_topup(uname text,mail text,amt int) returns int language plpgsql security definer set search_path=public as $$
declare uid uuid; m int;
begin
  if not is_dev() then raise exception 'Khusus developer'; end if;
  if amt is null or amt<1 or amt>10000000 then raise exception 'Jumlah Mora tidak valid'; end if;
  select p.id into uid from profiles p join auth.users u on u.id=p.id where p.username=lower(trim(uname)) and lower(u.email)=lower(trim(mail));
  if uid is null then raise exception 'Username dan Gmail tidak cocok'; end if;
  insert into wallets(user_id) values(uid) on conflict do nothing;
  update wallets set mora=mora+amt where user_id=uid returning mora into m;
  insert into topups(user_id,mora,by_dev) values(uid,amt,auth.uid());
  return m;
end $$;

-- Menu dev > Sandi: status semua pengguna (Aman / Tidak pantas), sandi asli tidak pernah dibaca
create or replace function public.dev_pw_all() returns table(id uuid,username text,email text,bad boolean) language sql stable security definer set search_path=public as $$
  select u.id,p.username,u.email::text,public.dev_pw_check(u.id) from auth.users u join public.profiles p on p.id=u.id where public.is_dev() order by 4 desc,2 $$;

-- Komentar gaya Facebook: balasan + suka komentar
alter table public.comments add column if not exists parent_id bigint references public.comments(id) on delete cascade;
create index if not exists comments_post_time on public.comments(post_id,created_at);
create table if not exists public.comment_likes(comment_id bigint references public.comments on delete cascade,user_id uuid references public.profiles on delete cascade,primary key(comment_id,user_id));
alter table public.comment_likes enable row level security;
drop policy if exists p_sel on public.comment_likes;
create policy p_sel on public.comment_likes for select to authenticated using (true);
drop policy if exists p_ins on public.comment_likes;
create policy p_ins on public.comment_likes for insert to authenticated with check (user_id=auth.uid() and not public.is_banned());
drop policy if exists p_del on public.comment_likes;
create policy p_del on public.comment_likes for delete to authenticated using (user_id=auth.uid());
grant select,insert,delete on public.comment_likes to authenticated;
create or replace function public.t_cparent() returns trigger language plpgsql security definer set search_path=public as $$
declare p public.comments;
begin
  if new.parent_id is not null then
    select * into p from public.comments where id=new.parent_id;
    if p.id is null then raise exception 'Komentar induk tidak ada'; end if;
    new.post_id:=p.post_id; new.parent_id:=coalesce(p.parent_id,p.id);
  end if;
  return new;
end $$;
drop trigger if exists cparent on public.comments;
create trigger cparent before insert on public.comments for each row execute function public.t_cparent();
do $$ begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='comment_likes') then
    alter publication supabase_realtime add table public.comment_likes;
  end if;
end $$;

-- Bubble pesan kustom hanya untuk akun terverifikasi
create or replace function public.t_bub() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if coalesce(new.s->'bub','null'::jsonb)<>'null'::jsonb and (new.s->'bub') is distinct from (old.s->'bub') and not (new.role='dev' or coalesce(new.verified_until>now(),false)) then
    raise exception 'Bubble khusus akun terverifikasi'; end if;
  return new;
end $$;
drop trigger if exists bub_chk on public.profiles;
create trigger bub_chk before update on public.profiles for each row execute function public.t_bub();

grant execute on function public.dev_topup(text,text,int),public.dev_pw_all(),public.buy_check(int),public.room_add(uuid,text,boolean),public.room_transfer(uuid,text) to authenticated;

-- ===================== UPDATE: Gmail asli + OTP, afinitas =====================
-- Gmail asli: hanya gmail.com / googlemail.com, satu Gmail satu akun (titik dan +alias dianggap sama)
create or replace function public.canon_gmail(e text) returns text language sql immutable set search_path=public as $$
  select case when lower(split_part(e,'@',2)) in ('gmail.com','googlemail.com') then replace(split_part(split_part(lower(e),'@',1),'+',1),'.','')||'@gmail.com' else lower(e) end $$;
create or replace function public.gmail_free(mail text) returns boolean language sql stable security definer set search_path=public as $$
  select not exists(select 1 from auth.users u where public.canon_gmail(u.email)=public.canon_gmail(mail)) $$;
create or replace function public.t_gmail() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.email is null then return new; end if;
  if lower(split_part(new.email,'@',2)) not in ('gmail.com','googlemail.com') then raise exception 'Gunakan Gmail asli'; end if;
  if not public.gmail_free(new.email) then raise exception 'Gmail sudah dipakai'; end if;
  return new;
end $$;
drop trigger if exists gmail_chk on auth.users;
create trigger gmail_chk before insert on auth.users for each row execute function public.t_gmail();
grant execute on function public.gmail_free(text) to anon, authenticated;
-- bersihkan akun yang tidak pernah verifikasi OTP (jalankan manual di SQL Editor: select public.purge_unverified();)
create or replace function public.purge_unverified() returns int language plpgsql security definer set search_path=public as $$
declare n int;
begin delete from auth.users where email_confirmed_at is null and created_at<now()-interval '1 day'; get diagnostics n=row_count; return n; end $$;
revoke execute on function public.purge_unverified() from public, anon, authenticated;

-- Afinitas (hubungan) seperti Mobile Legends: Pasangan (maks 1), Sahabat (maks 3), Saudara (maks 3)
create table if not exists public.affinities(
  id bigint generated always as identity primary key,
  a uuid not null references public.profiles on delete cascade,
  b uuid not null references public.profiles on delete cascade,
  kind text not null check (kind in ('pasangan','sahabat','saudara')),
  status text not null default 'pending' check (status in ('pending','active')),
  points int not null default 0,
  since timestamptz,
  last_a date, last_b date,
  created_at timestamptz not null default now(),
  check (a<>b));
create unique index if not exists affinities_pair on public.affinities(least(a,b),greatest(a,b));
alter table public.affinities enable row level security;
drop policy if exists p_sel on public.affinities;
create policy p_sel on public.affinities for select to authenticated using (status='active' or a=auth.uid() or b=auth.uid() or public.is_dev());
revoke insert,update,delete on public.affinities from authenticated;
grant select on public.affinities to authenticated;
create or replace function public.aff_request(target uuid,k text) returns void language plpgsql security definer set search_path=public as $$
declare me uuid:=auth.uid(); lim int; n1 int; n2 int;
begin
  if me is null or is_banned() then raise exception 'Tidak diizinkan'; end if;
  if target is null or target=me then raise exception 'Pengguna tidak valid'; end if;
  if k not in ('pasangan','sahabat','saudara') then raise exception 'Jenis afinitas tidak valid'; end if;
  if not exists(select 1 from profiles where id=target and not banned) then raise exception 'Pengguna tidak ditemukan'; end if;
  if not (exists(select 1 from follows where follower=me and following=target) and exists(select 1 from follows where follower=target and following=me)) then raise exception 'Kalian harus berteman (saling mengikuti) dulu'; end if;
  if exists(select 1 from affinities where least(a,b)=least(me,target) and greatest(a,b)=greatest(me,target)) then raise exception 'Afinitas dengan pengguna ini sudah ada'; end if;
  lim:=case k when 'pasangan' then 1 else 3 end;
  select count(*) into n1 from affinities where kind=k and (a=me or b=me);
  select count(*) into n2 from affinities where kind=k and status='active' and (a=target or b=target);
  if n1>=lim then raise exception 'Slot % kamu sudah penuh',k; end if;
  if n2>=lim then raise exception 'Slot % pengguna itu sudah penuh',k; end if;
  insert into affinities(a,b,kind) values(me,target,k);
end $$;
create or replace function public.aff_respond(rid bigint,ok boolean) returns void language plpgsql security definer set search_path=public as $$
declare me uuid:=auth.uid(); r public.affinities; lim int; n int;
begin
  select * into r from affinities where id=rid;
  if r.id is null or r.b is distinct from me or r.status<>'pending' then raise exception 'Permintaan tidak ditemukan'; end if;
  if not ok then delete from affinities where id=rid; return; end if;
  lim:=case r.kind when 'pasangan' then 1 else 3 end;
  select count(*) into n from affinities where kind=r.kind and status='active' and (a=me or b=me);
  if n>=lim then raise exception 'Slot % kamu sudah penuh',r.kind; end if;
  update affinities set status='active',since=now() where id=rid;
end $$;
create or replace function public.aff_end(rid bigint) returns void language plpgsql security definer set search_path=public as $$
begin delete from affinities where id=rid and (a=auth.uid() or b=auth.uid() or is_dev()); end $$;
create or replace function public.aff_checkin(rid bigint) returns int language plpgsql security definer set search_path=public as $$
declare me uuid:=auth.uid(); r public.affinities; d date:=(now() at time zone 'Asia/Jakarta')::date; p int;
begin
  select * into r from affinities where id=rid and status='active' and (a=me or b=me);
  if r.id is null then raise exception 'Afinitas tidak ditemukan'; end if;
  if (r.a=me and r.last_a=d) or (r.b=me and r.last_b=d) then raise exception 'Kamu sudah check-in hari ini'; end if;
  update affinities set points=points+case when (case when r.a=me then r.last_b else r.last_a end)=d then 15 else 10 end,
    last_a=case when a=me then d else last_a end, last_b=case when b=me then d else last_b end where id=rid returning points into p;
  return p;
end $$;
do $$ begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='affinities') then
    alter publication supabase_realtime add table public.affinities;
  end if;
end $$;
grant execute on function public.aff_request(uuid,text),public.aff_respond(bigint,boolean),public.aff_end(bigint),public.aff_checkin(bigint) to authenticated;
