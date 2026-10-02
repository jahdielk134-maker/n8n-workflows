-- Tables et fonction de recherche du pipeline RAG universel (workflows « RAG - … »)
-- À exécuter une fois dans Supabase : SQL Editor -> New query -> coller -> Run.
-- Les vecteurs ont 3 072 valeurs : c'est la taille du modèle gemini-embedding-001.
-- Les tables sont reliées par identifiant (suppression en cascade : supprimer un document supprime tout ce qui s'y rattache).

create extension if not exists vector;

create table if not exists rag_documents (
  id bigserial primary key,
  collection text not null,
  titre text not null,
  description text,
  source text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists rag_chunks (
  id bigserial primary key,
  document_id bigint not null references rag_documents(id) on delete cascade,
  ordre int not null,
  content text not null,
  contexte text,
  resume text,
  questions text[],
  metadata jsonb not null default '{}'::jsonb,
  unique (document_id, ordre)
);

create table if not exists rag_embeddings (
  chunk_id bigint primary key references rag_chunks(id) on delete cascade,
  embedding vector(3072) not null
);

create table if not exists rag_mots_cles (
  id bigserial primary key,
  chunk_id bigint not null references rag_chunks(id) on delete cascade,
  mot text not null
);

create table if not exists rag_entites (
  id bigserial primary key,
  chunk_id bigint not null references rag_chunks(id) on delete cascade,
  nom text not null,
  type text
);

create table if not exists rag_relations (
  id bigserial primary key,
  chunk_id bigint not null references rag_chunks(id) on delete cascade,
  sujet text not null,
  relation text not null,
  objet text not null
);

-- Historique des conversations du chat (une ligne par message, regroupées par session)
create table if not exists rag_messages (
  id bigserial primary key,
  session_id text not null,
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  created_at timestamptz not null default now()
);

create index if not exists rag_chunks_document_idx on rag_chunks(document_id);
create index if not exists rag_mots_cles_chunk_idx on rag_mots_cles(chunk_id);
create index if not exists rag_entites_chunk_idx on rag_entites(chunk_id);
create index if not exists rag_relations_chunk_idx on rag_relations(chunk_id);
create index if not exists rag_messages_session_idx on rag_messages (session_id, id);

-- Recherche vectorielle : les passages les plus proches, dans une collection (null = toutes)
create or replace function rag_match_chunks (
  query_embedding vector(3072),
  match_count int default 40,
  filter_collection text default null
) returns table (
  chunk_id bigint, document_id bigint, collection text, titre text, ordre int,
  content text, contexte text, resume text, similarity float,
  mots_cles text[], entites text[]
)
language sql stable as $$
  select c.id, d.id, d.collection, d.titre, c.ordre, c.content, c.contexte, c.resume,
         1 - (e.embedding <=> query_embedding) as similarity,
         coalesce((select array_agg(m.mot) from rag_mots_cles m where m.chunk_id = c.id), '{}'),
         coalesce((select array_agg(en.nom) from rag_entites en where en.chunk_id = c.id), '{}')
  from rag_embeddings e
  join rag_chunks c on c.id = e.chunk_id
  join rag_documents d on d.id = c.document_id
  where filter_collection is null or d.collection = filter_collection
  order by e.embedding <=> query_embedding
  limit match_count;
$$;
