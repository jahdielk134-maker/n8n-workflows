-- Table et fonction de recherche pour le workflow « Study case RAG Supabase »
-- À exécuter une fois dans Supabase : SQL Editor -> New query -> coller -> Run.
-- Les vecteurs ont 3 072 valeurs : c'est la taille du modèle gemini-embedding-001.
-- Avec une centaine de lignes, la recherche sans index est instantanée.

create extension if not exists vector;

create table if not exists embedding (
  id bigserial primary key,
  content text,
  metadata jsonb,
  embedding vector(3072)
);

create or replace function match_embedding (
  query_embedding vector(3072),
  match_count int default null,
  filter jsonb default '{}'
) returns table (id bigint, content text, metadata jsonb, similarity float)
language plpgsql as $$
#variable_conflict use_column
begin
  return query
  select id, content, metadata, 1 - (embedding <=> query_embedding) as similarity
  from embedding
  where metadata @> filter
  order by embedding <=> query_embedding
  limit match_count;
end;
$$;
