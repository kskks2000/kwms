DO $$
DECLARE
  schema_name constant text := 'kwms';
  default_tenant_id uuid;
  table_name text;
  policy_name text;
  refresh_policy_tables text[] := ARRAY[
    'audit_log_2026_06',
    'audit_log_default',
    'code_value',
    'country',
    'currency',
    'event_outbox',
    'permission',
    'role_permission',
    'shipment_package',
    'uom',
    'user_role',
    'wave_order'
  ];
BEGIN
  EXECUTE format('ALTER TABLE %I.tenant DISABLE ROW LEVEL SECURITY', schema_name);

  EXECUTE format('SELECT id FROM %I.tenant WHERE code = $1', schema_name)
  USING 'META'
  INTO default_tenant_id;

  IF default_tenant_id IS NULL THEN
    EXECUTE format('SELECT %I.uuid_generate_v7()', schema_name)
    INTO default_tenant_id;
  END IF;

  PERFORM set_config('app.current_tenant', default_tenant_id::text, true);

  EXECUTE format(
    'INSERT INTO %I.tenant (id, code, name, legal_name, is_active, locale, default_timezone)
     VALUES ($1, $2, $3, $4, true, $5, $6)
     ON CONFLICT (code) DO UPDATE
     SET name = EXCLUDED.name,
         legal_name = COALESCE(%I.tenant.legal_name, EXCLUDED.legal_name),
         is_active = true,
         updated_at = now()
     RETURNING id',
    schema_name,
    schema_name
  )
  USING default_tenant_id, 'META', 'Meta Seoul KWMS', 'Meta Seoul', 'ko-KR', 'Asia/Seoul'
  INTO default_tenant_id;

  PERFORM set_config('app.current_tenant', default_tenant_id::text, true);

  FOR table_name IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = schema_name
      AND c.relkind = 'r'
      AND c.relname <> 'tenant'
      AND NOT EXISTS (
        SELECT 1
        FROM pg_attribute a
        WHERE a.attrelid = c.oid
          AND a.attname = 'tenant_id'
          AND NOT a.attisdropped
      )
    ORDER BY c.relname
  LOOP
    EXECUTE format('ALTER TABLE %I.%I DISABLE ROW LEVEL SECURITY', schema_name, table_name);
    EXECUTE format('ALTER TABLE %I.%I ADD COLUMN IF NOT EXISTS tenant_id uuid', schema_name, table_name);
    EXECUTE format('UPDATE %I.%I SET tenant_id = $1 WHERE tenant_id IS NULL', schema_name, table_name)
    USING default_tenant_id;
    EXECUTE format('ALTER TABLE %I.%I ALTER COLUMN tenant_id SET NOT NULL', schema_name, table_name);

    IF NOT EXISTS (
      SELECT 1
      FROM pg_constraint con
      JOIN pg_class rel ON rel.oid = con.conrelid
      JOIN pg_namespace ns ON ns.oid = rel.relnamespace
      WHERE ns.nspname = schema_name
        AND rel.relname = table_name
        AND con.conname = left(table_name || '_tenant_id_fkey', 63)
    ) THEN
      EXECUTE format(
        'ALTER TABLE %I.%I ADD CONSTRAINT %I FOREIGN KEY (tenant_id) REFERENCES %I.tenant (id)',
        schema_name,
        table_name,
        left(table_name || '_tenant_id_fkey', 63),
        schema_name
      );
    END IF;
  END LOOP;

  FOR table_name IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a
      ON a.attrelid = c.oid
     AND a.attname = 'tenant_id'
     AND NOT a.attisdropped
    WHERE n.nspname = schema_name
      AND c.relkind = 'r'
    ORDER BY c.relname
  LOOP
    EXECUTE format('ALTER TABLE %I.%I DISABLE ROW LEVEL SECURITY', schema_name, table_name);
    EXECUTE format('UPDATE %I.%I SET tenant_id = $1 WHERE tenant_id IS NULL', schema_name, table_name)
    USING default_tenant_id;
    EXECUTE format('ALTER TABLE %I.%I ALTER COLUMN tenant_id SET NOT NULL', schema_name, table_name);
    EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON %I.%I (tenant_id)', left('idx_' || table_name || '_tenant_id', 63), schema_name, table_name);
    EXECUTE format('DROP TRIGGER IF EXISTS trg_set_tenant ON %I.%I', schema_name, table_name);
    EXECUTE format(
      'CREATE TRIGGER trg_set_tenant BEFORE INSERT ON %I.%I FOR EACH ROW EXECUTE FUNCTION %I.tg_set_tenant()',
      schema_name,
      table_name,
      schema_name
    );
  END LOOP;

  FOREACH table_name IN ARRAY refresh_policy_tables
  LOOP
    IF EXISTS (
      SELECT 1
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_attribute a
        ON a.attrelid = c.oid
       AND a.attname = 'tenant_id'
       AND NOT a.attisdropped
      WHERE n.nspname = schema_name
        AND c.relkind = 'r'
        AND c.relname = table_name
    ) THEN
      FOR policy_name IN
        SELECT pol.polname
        FROM pg_policy pol
        JOIN pg_class cls ON cls.oid = pol.polrelid
        JOIN pg_namespace ns ON ns.oid = cls.relnamespace
        WHERE ns.nspname = schema_name
          AND cls.relname = table_name
      LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', policy_name, schema_name, table_name);
      END LOOP;

      EXECUTE format(
        'CREATE POLICY rls_tenant_isolation ON %I.%I FOR ALL USING (tenant_id = %I.current_tenant_id()) WITH CHECK (tenant_id = %I.current_tenant_id())',
        schema_name,
        table_name,
        schema_name,
        schema_name
      );
    END IF;
  END LOOP;

  FOR table_name IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a
      ON a.attrelid = c.oid
     AND a.attname = 'tenant_id'
     AND NOT a.attisdropped
    WHERE n.nspname = schema_name
      AND c.relkind = 'r'
    ORDER BY c.relname
  LOOP
    EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', schema_name, table_name);
    EXECUTE format('ALTER TABLE %I.%I FORCE ROW LEVEL SECURITY', schema_name, table_name);
  END LOOP;

  EXECUTE format('ALTER TABLE %I.tenant ENABLE ROW LEVEL SECURITY', schema_name);
  EXECUTE format('ALTER TABLE %I.tenant FORCE ROW LEVEL SECURITY', schema_name);

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policy pol
    JOIN pg_class cls ON cls.oid = pol.polrelid
    JOIN pg_namespace ns ON ns.oid = cls.relnamespace
    WHERE ns.nspname = schema_name
      AND cls.relname = 'tenant'
      AND pol.polname = 'rls_current_tenant_only'
  ) THEN
    EXECUTE format(
      'CREATE POLICY rls_current_tenant_only ON %I.tenant FOR ALL USING (id = %I.current_tenant_id()) WITH CHECK (id = %I.current_tenant_id())',
      schema_name,
      schema_name,
      schema_name
    );
  END IF;
END $$;
