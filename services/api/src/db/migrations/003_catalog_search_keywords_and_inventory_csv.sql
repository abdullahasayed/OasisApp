CREATE EXTENSION IF NOT EXISTS pg_trgm;

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS search_keywords TEXT[] NOT NULL DEFAULT '{}'::text[];

CREATE INDEX IF NOT EXISTS idx_products_catalog_document
  ON products USING gin (
    (
      setweight(to_tsvector('simple', COALESCE(name, '')), 'A') ||
      setweight(to_tsvector('simple', COALESCE(array_to_string(search_keywords, ' '), '')), 'B') ||
      setweight(to_tsvector('simple', COALESCE(description, '')), 'C')
    )
  );

CREATE INDEX IF NOT EXISTS idx_products_name_trgm
  ON products USING gin (name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_products_search_keywords_trgm
  ON products USING gin ((array_to_string(search_keywords, ' ')) gin_trgm_ops);
