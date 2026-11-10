-- PostgreSQL 18 conversion of the supplied Oracle 19c schema.
-- Source SHA-256: 7E781F7AF6EF68597314C7E7953D304F3C5827155F3F586DAF180BC50E549DF3
-- Preserves quoted identifiers, 69 tables, relationships, precision and uniqueness.
-- PostgreSQL DDL is transactional; the whole schema rolls back on failure.

BEGIN;
SET LOCAL TIME ZONE 'Asia/Yangon';

-- 02 Branches and coverage

CREATE TABLE "BRANCHES" (
  "ID"                               UUID               NOT NULL,
  "CODE"                             VARCHAR(200)    NOT NULL,
  "NAME"                             VARCHAR(1000)   NOT NULL,
  "ADDRESS_TEXT"                     TEXT                  NOT NULL,
  "PHONE"                            VARCHAR(1000)   NOT NULL,
  "TIME_ZONE"                        VARCHAR(1000)   NOT NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  "CREATED_AT"                       TIMESTAMPTZ(6)          NOT NULL,
  CONSTRAINT "PK_BRANCHES" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_BRANCHES_B75F9A51" UNIQUE ("CODE"),
  CONSTRAINT "CK_BRANCHES_8DFA468F" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

CREATE TABLE "WAREHOUSES" (
  "ID"                               UUID               NOT NULL,
  "BRANCH_ID"                        UUID               NOT NULL,
  "CODE"                             VARCHAR(200)    NOT NULL,
  "NAME"                             VARCHAR(1000)   NOT NULL,
  "ADDRESS_TEXT"                     TEXT                  NOT NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  CONSTRAINT "PK_WAREHOUSES" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_WAREHOUSES_8DFBEB63" UNIQUE ("BRANCH_ID", "CODE"),
  CONSTRAINT "UK_WAREHOUSES_E328968D" UNIQUE ("BRANCH_ID", "ID"),
  CONSTRAINT "CK_WAREHOUSES_7CA73072" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

CREATE TABLE "TOWNSHIPS" (
  "ID"                               UUID               NOT NULL,
  "CODE"                             VARCHAR(200)    NOT NULL,
  "NAME_MM"                          VARCHAR(1000)   NOT NULL,
  "NAME_EN"                          VARCHAR(1000)   NULL,
  "REGION_NAME"                      VARCHAR(1000)   NOT NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  CONSTRAINT "PK_TOWNSHIPS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_TOWNSHIPS_EEAAB3DF" UNIQUE ("CODE"),
  CONSTRAINT "CK_TOWNSHIPS_88466DCC" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

CREATE TABLE "BRANCH_SERVICE_AREAS" (
  "ID"                               UUID               NOT NULL,
  "BRANCH_ID"                        UUID               NOT NULL,
  "SERVICE_AREA_ID"                  UUID               NOT NULL,
  "PRIORITY_RANK"                    INTEGER               NOT NULL,
  "DELIVERY_FEE"                     NUMERIC(18,2)          NOT NULL,
  "MINIMUM_ORDER"                    NUMERIC(18,2)          NOT NULL,
  "CURRENCY"                         CHAR(3)          NOT NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  CONSTRAINT "PK_BRANCH_SERVICE_AREAS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_BRANCH_SERVICE_AR_D143E7D9" UNIQUE ("BRANCH_ID", "SERVICE_AREA_ID"),
  CONSTRAINT "UK_BRANCH_SERVICE_AR_95EE407F" UNIQUE ("SERVICE_AREA_ID", "PRIORITY_RANK"),
  CONSTRAINT "CK_BRANCH_SERVICE_AR_53DF297B" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

CREATE TABLE "SERVICE_AREAS" (
  "ID"                               UUID               NOT NULL,
  "TOWNSHIP_ID"                      UUID               NOT NULL,
  "CODE"                             VARCHAR(200)    NOT NULL,
  "NAME"                             VARCHAR(1000)   NOT NULL,
  "BOUNDARY_GEOJSON"                 JSONB                  NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  CONSTRAINT "PK_SERVICE_AREAS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_SERVICE_AREAS_7DDB18E4" UNIQUE ("TOWNSHIP_ID", "CODE"),
  CONSTRAINT "CK_SERVICE_AREAS_BD13EFB0" CHECK ("BOUNDARY_GEOJSON" IS JSON),
  CONSTRAINT "CK_SERVICE_AREAS_FF414BB6" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

-- 03 Identity roles and permissions

CREATE TABLE "USERS" (
  "ID"                               UUID               NOT NULL,
  "PHONE"                            VARCHAR(200)    NOT NULL,
  "DISPLAY_NAME"                     VARCHAR(1000)   NOT NULL,
  "EMAIL"                            VARCHAR(1000)   NULL,
  "PASSWORD_HASH"                    VARCHAR(1000)   NULL,
  "ACCOUNT_STATUS"                   VARCHAR(1000)   NOT NULL,
  "PHONE_VERIFIED_AT"                TIMESTAMPTZ(6)          NULL,
  "CREATED_AT"                       TIMESTAMPTZ(6)          NOT NULL,
  CONSTRAINT "PK_USERS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_USERS_9D2EA286" UNIQUE ("PHONE")
);

CREATE TABLE "USER_ROLES" (
  "ID"                               UUID               NOT NULL,
  "USER_ID"                          UUID               NOT NULL,
  "ROLE_ID"                          UUID               NOT NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  CONSTRAINT "PK_USER_ROLES" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_USER_ROLES_56F7B8FF" UNIQUE ("USER_ID", "ROLE_ID"),
  CONSTRAINT "CK_USER_ROLES_EC2D778C" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

CREATE TABLE "ROLES" (
  "ID"                               UUID               NOT NULL,
  "CODE"                             VARCHAR(200)    NOT NULL,
  "NAME"                             VARCHAR(1000)   NOT NULL,
  "SCOPE_MODE"                       VARCHAR(1000)   NOT NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  CONSTRAINT "PK_ROLES" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_ROLES_FA2A4F1E" UNIQUE ("CODE"),
  CONSTRAINT "CK_ROLES_A8DFF63C" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

CREATE TABLE "AUDIT_LOGS" (
  "ID"                               UUID               NOT NULL,
  "ACTOR_USER_ID"                    UUID               NULL,
  "BRANCH_ID"                        UUID               NULL,
  "ACTION_CODE"                      VARCHAR(1000)   NOT NULL,
  "ENTITY_TYPE"                      VARCHAR(1000)   NOT NULL,
  "ENTITY_IDENTIFIER"                VARCHAR(1000)   NOT NULL,
  "BEFORE_JSON"                      JSONB                  NULL,
  "AFTER_JSON"                       JSONB                  NULL,
  "REQUEST_ID"                       VARCHAR(1000)   NULL,
  "OCCURRED_AT"                      TIMESTAMPTZ(6)          NOT NULL,
  CONSTRAINT "PK_AUDIT_LOGS" PRIMARY KEY ("ID"),
  CONSTRAINT "CK_AUDIT_LOGS_AF5A7DDC" CHECK ("BEFORE_JSON" IS JSON),
  CONSTRAINT "CK_AUDIT_LOGS_71748B06" CHECK ("AFTER_JSON" IS JSON)
);

CREATE TABLE "USER_ROLE_BRANCHES" (
  "ID"                               UUID               NOT NULL,
  "USER_ROLE_ID"                     UUID               NOT NULL,
  "BRANCH_ID"                        UUID               NOT NULL,
  CONSTRAINT "PK_USER_ROLE_BRANCHES" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_USER_ROLE_BRANCHE_11D261C7" UNIQUE ("USER_ROLE_ID", "BRANCH_ID")
);

CREATE TABLE "ROLE_PERMISSIONS" (
  "ID"                               UUID               NOT NULL,
  "ROLE_ID"                          UUID               NOT NULL,
  "PERMISSION_ID"                    UUID               NOT NULL,
  CONSTRAINT "PK_ROLE_PERMISSIONS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_ROLE_PERMISSIONS_3F414C67" UNIQUE ("ROLE_ID", "PERMISSION_ID")
);

CREATE TABLE "MENUS" (
  "ID"                               UUID               NOT NULL,
  "PARENT_MENU_ID"                   UUID               NULL,
  "CODE"                             VARCHAR(200)    NOT NULL,
  "LABEL"                            VARCHAR(1000)   NOT NULL,
  "ROUTE"                            VARCHAR(1000)   NULL,
  "SORT_ORDER"                       INTEGER               NOT NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  CONSTRAINT "PK_MENUS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_MENUS_253D8C2A" UNIQUE ("CODE"),
  CONSTRAINT "CK_MENUS_5F58C976" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

CREATE TABLE "PERMISSIONS" (
  "ID"                               UUID               NOT NULL,
  "MENU_ID"                          UUID               NOT NULL,
  "ACTION_CODE"                      VARCHAR(200)    NOT NULL,
  "DESCRIPTION"                      TEXT                  NOT NULL,
  CONSTRAINT "PK_PERMISSIONS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_PERMISSIONS_23C6F1B6" UNIQUE ("MENU_ID", "ACTION_CODE")
);

-- 04 Households preferences and pantry

CREATE TABLE "HOUSEHOLDS" (
  "ID"                               UUID               NOT NULL,
  "OWNER_USER_ID"                    UUID               NOT NULL,
  "NAME"                             VARCHAR(1000)   NOT NULL,
  "WEEKLY_BUDGET"                    NUMERIC(18,2)          NULL,
  "CURRENCY"                         CHAR(3)          NOT NULL,
  "MAX_COOKING_MINUTES"              INTEGER               NULL,
  "CREATED_AT"                       TIMESTAMPTZ(6)          NOT NULL,
  CONSTRAINT "PK_HOUSEHOLDS" PRIMARY KEY ("ID")
);

CREATE TABLE "HOUSEHOLD_MEMBERS" (
  "ID"                               UUID               NOT NULL,
  "HOUSEHOLD_ID"                     UUID               NOT NULL,
  "DISPLAY_NAME"                     VARCHAR(1000)   NOT NULL,
  "AGE_GROUP"                        VARCHAR(1000)   NOT NULL,
  "SERVING_FACTOR"                   NUMERIC(18,6)          NOT NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  CONSTRAINT "PK_HOUSEHOLD_MEMBERS" PRIMARY KEY ("ID"),
  CONSTRAINT "CK_HOUSEHOLD_MEMBERS_EC4B6024" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

CREATE TABLE "CUSTOMER_ADDRESSES" (
  "ID"                               UUID               NOT NULL,
  "HOUSEHOLD_ID"                     UUID               NOT NULL,
  "SERVICE_AREA_ID"                  UUID               NOT NULL,
  "RECIPIENT_NAME"                   VARCHAR(1000)   NOT NULL,
  "RECIPIENT_PHONE"                  VARCHAR(1000)   NOT NULL,
  "ADDRESS_TEXT"                     TEXT                  NOT NULL,
  "LATITUDE"                         NUMERIC(10,7)          NULL,
  "LONGITUDE"                        NUMERIC(10,7)          NULL,
  "DELIVERY_INSTRUCTIONS"            TEXT                  NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  CONSTRAINT "PK_CUSTOMER_ADDRESSES" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_CUSTOMER_ADDRESSE_A903CEFC" UNIQUE ("HOUSEHOLD_ID", "ID"),
  CONSTRAINT "CK_CUSTOMER_ADDRESSE_60A793E0" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

CREATE TABLE "PANTRY_ITEMS" (
  "ID"                               UUID               NOT NULL,
  "HOUSEHOLD_ID"                     UUID               NOT NULL,
  "INGREDIENT_ID"                    UUID               NOT NULL,
  "QUANTITY_BASE"                    NUMERIC(18,6)          NOT NULL,
  "UPDATED_AT"                       TIMESTAMPTZ(6)          NOT NULL,
  CONSTRAINT "PK_PANTRY_ITEMS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_PANTRY_ITEMS_499A8935" UNIQUE ("HOUSEHOLD_ID", "INGREDIENT_ID")
);

CREATE TABLE "MEMBER_ALLERGENS" (
  "ID"                               UUID               NOT NULL,
  "HOUSEHOLD_MEMBER_ID"              UUID               NOT NULL,
  "ALLERGEN_ID"                      UUID               NOT NULL,
  "NOTES"                            TEXT                  NULL,
  CONSTRAINT "PK_MEMBER_ALLERGENS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_MEMBER_ALLERGENS_BBFAD81F" UNIQUE ("HOUSEHOLD_MEMBER_ID", "ALLERGEN_ID")
);

CREATE TABLE "HOUSEHOLD_INGREDIENT_PREFERENCES" (
  "ID"                               UUID               NOT NULL,
  "HOUSEHOLD_ID"                     UUID               NOT NULL,
  "INGREDIENT_ID"                    UUID               NOT NULL,
  "PREFERENCE"                       VARCHAR(1000)   NOT NULL,
  CONSTRAINT "PK_HOUSEHOLD_INGREDIENT_PREFERENCES" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_HOUSEHOLD_INGREDI_C4B488AF" UNIQUE ("HOUSEHOLD_ID", "INGREDIENT_ID")
);

CREATE TABLE "HOUSEHOLD_DIETARY_PROFILES" (
  "ID"                               UUID               NOT NULL,
  "HOUSEHOLD_ID"                     UUID               NOT NULL,
  "DIETARY_PROFILE_ID"               UUID               NOT NULL,
  CONSTRAINT "PK_HOUSEHOLD_DIETARY_PROFILES" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_HOUSEHOLD_DIETARY_123701BC" UNIQUE ("HOUSEHOLD_ID", "DIETARY_PROFILE_ID")
);

-- 05 Ingredients products and branch prices

CREATE TABLE "UNITS" (
  "ID"                               UUID               NOT NULL,
  "CODE"                             VARCHAR(200)    NOT NULL,
  "NAME_MM"                          VARCHAR(1000)   NOT NULL,
  "DIMENSION"                        VARCHAR(1000)   NOT NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  CONSTRAINT "PK_UNITS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_UNITS_79964A78" UNIQUE ("CODE"),
  CONSTRAINT "CK_UNITS_1F1E0A26" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

CREATE TABLE "INGREDIENTS" (
  "ID"                               UUID               NOT NULL,
  "CODE"                             VARCHAR(200)    NOT NULL,
  "NAME_MM"                          VARCHAR(1000)   NOT NULL,
  "CATEGORY_CODE"                    VARCHAR(1000)   NOT NULL,
  "FOOD_GROUP_CODE"                  VARCHAR(1000)   NOT NULL,
  "BASE_UNIT_ID"                     UUID               NOT NULL,
  "STORAGE_GUIDANCE"                 TEXT                  NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  CONSTRAINT "PK_INGREDIENTS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_INGREDIENTS_679F2E6D" UNIQUE ("CODE"),
  CONSTRAINT "CK_INGREDIENTS_6F64B105" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

CREATE TABLE "INGREDIENT_MEASURES" (
  "ID"                               UUID               NOT NULL,
  "INGREDIENT_ID"                    UUID               NOT NULL,
  "UNIT_ID"                          UUID               NOT NULL,
  "BASE_QUANTITY"                    NUMERIC(18,6)          NOT NULL,
  "SOURCE_NOTE"                      TEXT                  NULL,
  CONSTRAINT "PK_INGREDIENT_MEASURES" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_INGREDIENT_MEASUR_70214E1D" UNIQUE ("INGREDIENT_ID", "UNIT_ID")
);

CREATE TABLE "ALLERGENS" (
  "ID"                               UUID               NOT NULL,
  "CODE"                             VARCHAR(200)    NOT NULL,
  "NAME"                             VARCHAR(1000)   NOT NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  CONSTRAINT "PK_ALLERGENS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_ALLERGENS_09C53D67" UNIQUE ("CODE"),
  CONSTRAINT "CK_ALLERGENS_DDAFCF59" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

CREATE TABLE "INGREDIENT_ALLERGENS" (
  "ID"                               UUID               NOT NULL,
  "INGREDIENT_ID"                    UUID               NOT NULL,
  "ALLERGEN_ID"                      UUID               NOT NULL,
  CONSTRAINT "PK_INGREDIENT_ALLERGENS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_INGREDIENT_ALLERG_62388CCB" UNIQUE ("INGREDIENT_ID", "ALLERGEN_ID")
);

CREATE TABLE "PRODUCTS" (
  "ID"                               UUID               NOT NULL,
  "SKU"                              VARCHAR(200)    NOT NULL,
  "INGREDIENT_ID"                    UUID               NOT NULL,
  "NAME"                             VARCHAR(1000)   NOT NULL,
  "PACK_QUANTITY"                    NUMERIC(18,6)          NOT NULL,
  "PACK_UNIT_ID"                     UUID               NOT NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  CONSTRAINT "PK_PRODUCTS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_PRODUCTS_10B4531D" UNIQUE ("SKU"),
  CONSTRAINT "CK_PRODUCTS_5E2A6390" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

CREATE TABLE "BRANCH_PRODUCTS" (
  "ID"                               UUID               NOT NULL,
  "BRANCH_ID"                        UUID               NOT NULL,
  "PRODUCT_ID"                       UUID               NOT NULL,
  "IS_AVAILABLE"                     BOOLEAN           NOT NULL,
  "REORDER_LEVEL_PACKS"              INTEGER               NOT NULL,
  CONSTRAINT "PK_BRANCH_PRODUCTS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_BRANCH_PRODUCTS_C37DAF9A" UNIQUE ("BRANCH_ID", "PRODUCT_ID"),
  CONSTRAINT "UK_BRANCH_PRODUCTS_ACA6D5E4" UNIQUE ("BRANCH_ID", "ID"),
  CONSTRAINT "UK_BRANCH_PRODUCTS_752344BE" UNIQUE ("BRANCH_ID", "ID", "PRODUCT_ID"),
  CONSTRAINT "CK_BRANCH_PRODUCTS_B6CBA6CE" CHECK ("IS_AVAILABLE" IN (FALSE, TRUE))
);

CREATE TABLE "BRANCH_PRICES" (
  "ID"                               UUID               NOT NULL,
  "BRANCH_PRODUCT_ID"                UUID               NOT NULL,
  "UNIT_PRICE"                       NUMERIC(18,2)          NOT NULL,
  "CURRENCY"                         CHAR(3)          NOT NULL,
  "VALID_FROM"                       TIMESTAMPTZ(6)          NOT NULL,
  "VALID_TO"                         TIMESTAMPTZ(6)          NULL,
  "CREATED_BY"                       UUID               NOT NULL,
  CONSTRAINT "PK_BRANCH_PRICES" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_BRANCH_PRICES_D90BCF0D" UNIQUE ("BRANCH_PRODUCT_ID", "VALID_FROM")
);

-- 06 Recipes meal types and pairing

CREATE TABLE "RECIPES" (
  "ID"                               UUID               NOT NULL,
  "CODE"                             VARCHAR(200)    NOT NULL,
  "CATEGORY_CODE"                    VARCHAR(1000)   NOT NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  "CREATED_BY"                       UUID               NOT NULL,
  "CREATED_AT"                       TIMESTAMPTZ(6)          NOT NULL,
  CONSTRAINT "PK_RECIPES" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_RECIPES_DDFD6603" UNIQUE ("CODE"),
  CONSTRAINT "CK_RECIPES_AD9E4DDC" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

CREATE TABLE "RECIPE_VERSIONS" (
  "ID"                               UUID               NOT NULL,
  "RECIPE_ID"                        UUID               NOT NULL,
  "VERSION_NO"                       INTEGER               NOT NULL,
  "TITLE_MM"                         VARCHAR(1000)   NOT NULL,
  "BASE_SERVINGS"                    NUMERIC(18,6)          NOT NULL,
  "PREP_MINUTES"                     INTEGER               NOT NULL,
  "COOK_MINUTES"                     INTEGER               NOT NULL,
  "INSTRUCTIONS"                     TEXT                  NOT NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  "APPROVED_BY"                      UUID               NULL,
  "PUBLISHED_AT"                     TIMESTAMPTZ(6)          NULL,
  CONSTRAINT "PK_RECIPE_VERSIONS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_RECIPE_VERSIONS_DD3C04EE" UNIQUE ("RECIPE_ID", "VERSION_NO")
);

CREATE TABLE "RECIPE_INGREDIENTS" (
  "ID"                               UUID               NOT NULL,
  "RECIPE_VERSION_ID"                UUID               NOT NULL,
  "LINE_NO"                          INTEGER               NOT NULL,
  "INGREDIENT_ID"                    UUID               NOT NULL,
  "UNIT_ID"                          UUID               NOT NULL,
  "QUANTITY"                         NUMERIC(18,6)          NOT NULL,
  "PREPARATION_NOTE"                 TEXT                  NULL,
  CONSTRAINT "PK_RECIPE_INGREDIENTS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_RECIPE_INGREDIENT_FD2DC717" UNIQUE ("RECIPE_VERSION_ID", "LINE_NO")
);

CREATE TABLE "MEAL_TYPES" (
  "ID"                               UUID               NOT NULL,
  "CODE"                             VARCHAR(200)    NOT NULL,
  "NAME_MM"                          VARCHAR(1000)   NOT NULL,
  "SORT_ORDER"                       INTEGER               NOT NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  CONSTRAINT "PK_MEAL_TYPES" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_MEAL_TYPES_05C62F82" UNIQUE ("CODE"),
  CONSTRAINT "CK_MEAL_TYPES_A5E31BD4" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

CREATE TABLE "RECIPE_MEAL_TYPES" (
  "ID"                               UUID               NOT NULL,
  "RECIPE_VERSION_ID"                UUID               NOT NULL,
  "MEAL_TYPE_ID"                     UUID               NOT NULL,
  CONSTRAINT "PK_RECIPE_MEAL_TYPES" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_RECIPE_MEAL_TYPES_1E026AD3" UNIQUE ("RECIPE_VERSION_ID", "MEAL_TYPE_ID")
);

CREATE TABLE "RECIPE_PAIRINGS" (
  "ID"                               UUID               NOT NULL,
  "RECIPE_VERSION_ID"                UUID               NOT NULL,
  "COMPANION_VERSION_ID"             UUID               NOT NULL,
  "COMPATIBILITY_SCORE"              INTEGER               NOT NULL,
  "REASON"                           TEXT                  NULL,
  CONSTRAINT "PK_RECIPE_PAIRINGS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_RECIPE_PAIRINGS_B17A232E" UNIQUE ("RECIPE_VERSION_ID", "COMPANION_VERSION_ID")
);

-- 07 Nutrition and planning rule setup

CREATE TABLE "NUTRIENTS" (
  "ID"                               UUID               NOT NULL,
  "CODE"                             VARCHAR(200)    NOT NULL,
  "NAME"                             VARCHAR(1000)   NOT NULL,
  "UNIT_ID"                          UUID               NOT NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  CONSTRAINT "PK_NUTRIENTS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_NUTRIENTS_A54006CC" UNIQUE ("CODE"),
  CONSTRAINT "CK_NUTRIENTS_54FBAF67" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

CREATE TABLE "INGREDIENT_NUTRIENTS" (
  "ID"                               UUID               NOT NULL,
  "INGREDIENT_ID"                    UUID               NOT NULL,
  "NUTRIENT_ID"                      UUID               NOT NULL,
  "BASIS_QUANTITY"                   NUMERIC(18,6)          NOT NULL,
  "BASIS_UNIT_ID"                    UUID               NOT NULL,
  "NUTRIENT_AMOUNT"                  NUMERIC(18,6)          NOT NULL,
  "SOURCE_REFERENCE"                 VARCHAR(1000)   NOT NULL,
  "VERIFIED_AT"                      TIMESTAMPTZ(6)          NULL,
  CONSTRAINT "PK_INGREDIENT_NUTRIENTS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_INGREDIENT_NUTRIE_269B4964" UNIQUE ("INGREDIENT_ID", "NUTRIENT_ID")
);

CREATE TABLE "DIETARY_PROFILES" (
  "ID"                               UUID               NOT NULL,
  "CODE"                             VARCHAR(200)    NOT NULL,
  "VERSION_NO"                       INTEGER               NOT NULL,
  "NAME"                             VARCHAR(1000)   NOT NULL,
  "CONSTRAINTS_JSON"                 JSONB                  NOT NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  "APPROVED_BY"                      UUID               NULL,
  "PUBLISHED_AT"                     TIMESTAMPTZ(6)          NULL,
  CONSTRAINT "PK_DIETARY_PROFILES" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_DIETARY_PROFILES_D9ED3F10" UNIQUE ("CODE", "VERSION_NO"),
  CONSTRAINT "CK_DIETARY_PROFILES_FF8CAF69" CHECK ("CONSTRAINTS_JSON" IS JSON)
);

CREATE TABLE "PLANNING_RULE_SETS" (
  "ID"                               UUID               NOT NULL,
  "CODE"                             VARCHAR(200)    NOT NULL,
  "VERSION_NO"                       INTEGER               NOT NULL,
  "NAME"                             VARCHAR(1000)   NOT NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  "APPROVED_BY"                      UUID               NULL,
  "PUBLISHED_AT"                     TIMESTAMPTZ(6)          NULL,
  CONSTRAINT "PK_PLANNING_RULE_SETS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_PLANNING_RULE_SET_BB3A53AC" UNIQUE ("CODE", "VERSION_NO")
);

CREATE TABLE "PLANNING_RULES" (
  "ID"                               UUID               NOT NULL,
  "RULE_SET_ID"                      UUID               NOT NULL,
  "CODE"                             VARCHAR(200)    NOT NULL,
  "RULE_TYPE"                        VARCHAR(1000)   NOT NULL,
  "CONSTRAINT_LEVEL"                 VARCHAR(1000)   NOT NULL,
  "PRIORITY_WEIGHT"                  NUMERIC(18,6)          NOT NULL,
  "PARAMETERS_JSON"                  JSONB                  NOT NULL,
  "EXPLANATION"                      TEXT                  NOT NULL,
  CONSTRAINT "PK_PLANNING_RULES" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_PLANNING_RULES_45A6C1AF" UNIQUE ("RULE_SET_ID", "CODE"),
  CONSTRAINT "CK_PLANNING_RULES_BBB5CAF8" CHECK ("PARAMETERS_JSON" IS JSON)
);

-- 08 Meal plans shopping lists and carts

CREATE TABLE "MEAL_PLANS" (
  "ID"                               UUID               NOT NULL,
  "HOUSEHOLD_ID"                     UUID               NOT NULL,
  "REFERENCE_BRANCH_ID"              UUID               NULL,
  "RULE_SET_ID"                      UUID               NOT NULL,
  "WEEK_START"                       DATE                  NOT NULL,
  "REVISION_NO"                      INTEGER               NOT NULL,
  "BUDGET_LIMIT"                     NUMERIC(18,2)          NULL,
  "CURRENCY"                         CHAR(3)          NOT NULL,
  "DIETARY_SNAPSHOT"                 JSONB                  NOT NULL,
  "ESTIMATED_FOOD_COST"              NUMERIC(18,2)          NULL,
  "ESTIMATED_PACK_COST"              NUMERIC(18,2)          NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  "CREATED_AT"                       TIMESTAMPTZ(6)          NOT NULL,
  CONSTRAINT "PK_MEAL_PLANS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_MEAL_PLANS_3DA17D14" UNIQUE ("HOUSEHOLD_ID", "WEEK_START", "REVISION_NO"),
  CONSTRAINT "UK_MEAL_PLANS_BEF07A61" UNIQUE ("HOUSEHOLD_ID", "ID"),
  CONSTRAINT "CK_MEAL_PLANS_682C5B8B" CHECK ("DIETARY_SNAPSHOT" IS JSON)
);

CREATE TABLE "MEAL_SLOTS" (
  "ID"                               UUID               NOT NULL,
  "MEAL_PLAN_ID"                     UUID               NOT NULL,
  "MEAL_DATE"                        DATE                  NOT NULL,
  "MEAL_TYPE_ID"                     UUID               NOT NULL,
  "DINER_COUNT"                      INTEGER               NOT NULL,
  "SERVING_UNITS"                    NUMERIC(18,6)          NOT NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  CONSTRAINT "PK_MEAL_SLOTS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_MEAL_SLOTS_09A4D3C5" UNIQUE ("MEAL_PLAN_ID", "MEAL_DATE", "MEAL_TYPE_ID")
);

CREATE TABLE "MEAL_SLOT_RECIPES" (
  "ID"                               UUID               NOT NULL,
  "MEAL_SLOT_ID"                     UUID               NOT NULL,
  "RECIPE_VERSION_ID"                UUID               NOT NULL,
  "POSITION_NO"                      INTEGER               NOT NULL,
  "DISH_ROLE"                        VARCHAR(1000)   NOT NULL,
  "SERVING_MULTIPLIER"               NUMERIC(18,6)          NOT NULL,
  "NUTRITION_SNAPSHOT"               JSONB                  NOT NULL,
  CONSTRAINT "PK_MEAL_SLOT_RECIPES" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_MEAL_SLOT_RECIPES_353BB7E8" UNIQUE ("MEAL_SLOT_ID", "POSITION_NO"),
  CONSTRAINT "CK_MEAL_SLOT_RECIPES_D2A76F23" CHECK ("NUTRITION_SNAPSHOT" IS JSON)
);

CREATE TABLE "SHOPPING_LISTS" (
  "ID"                               UUID               NOT NULL,
  "HOUSEHOLD_ID"                     UUID               NOT NULL,
  "MEAL_PLAN_ID"                     UUID               NOT NULL,
  "REVISION_NO"                      INTEGER               NOT NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  "GENERATED_AT"                     TIMESTAMPTZ(6)          NOT NULL,
  CONSTRAINT "PK_SHOPPING_LISTS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_SHOPPING_LISTS_08D0BC47" UNIQUE ("MEAL_PLAN_ID", "REVISION_NO"),
  CONSTRAINT "UK_SHOPPING_LISTS_EB4F0F72" UNIQUE ("HOUSEHOLD_ID", "ID")
);

CREATE TABLE "SHOPPING_ITEMS" (
  "ID"                               UUID               NOT NULL,
  "SHOPPING_LIST_ID"                 UUID               NOT NULL,
  "INGREDIENT_ID"                    UUID               NOT NULL,
  "REQUIRED_BASE_QTY"                NUMERIC(18,6)          NOT NULL,
  "PANTRY_BASE_QTY"                  NUMERIC(18,6)          NOT NULL,
  "OUTSIDE_BASE_QTY"                 NUMERIC(18,6)          NOT NULL,
  "PORTAL_BASE_QTY"                  NUMERIC(18,6)          NOT NULL,
  CONSTRAINT "PK_SHOPPING_ITEMS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_SHOPPING_ITEMS_E53DD888" UNIQUE ("SHOPPING_LIST_ID", "INGREDIENT_ID")
);

CREATE TABLE "MEAL_FEEDBACK" (
  "ID"                               UUID               NOT NULL,
  "MEAL_SLOT_RECIPE_ID"              UUID               NOT NULL,
  "USER_ID"                          UUID               NOT NULL,
  "RATING"                           INTEGER               NOT NULL,
  "COMMENT"                          TEXT                  NULL,
  "CREATED_AT"                       TIMESTAMPTZ(6)          NOT NULL,
  CONSTRAINT "PK_MEAL_FEEDBACK" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_MEAL_FEEDBACK_26499C60" UNIQUE ("MEAL_SLOT_RECIPE_ID", "USER_ID")
);

CREATE TABLE "CARTS" (
  "ID"                               UUID               NOT NULL,
  "HOUSEHOLD_ID"                     UUID               NOT NULL,
  "BRANCH_ID"                        UUID               NOT NULL,
  "ADDRESS_ID"                       UUID               NULL,
  "SHOPPING_LIST_ID"                 UUID               NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  "UPDATED_AT"                       TIMESTAMPTZ(6)          NOT NULL,
  CONSTRAINT "PK_CARTS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_CARTS_EA2D0390" UNIQUE ("BRANCH_ID", "ID"),
  CONSTRAINT "UK_CARTS_4E8749E2" UNIQUE ("BRANCH_ID", "HOUSEHOLD_ID", "ID")
);

CREATE TABLE "CART_ITEMS" (
  "ID"                               UUID               NOT NULL,
  "BRANCH_ID"                        UUID               NOT NULL,
  "CART_ID"                          UUID               NOT NULL,
  "BRANCH_PRODUCT_ID"                UUID               NOT NULL,
  "SHOPPING_ITEM_ID"                 UUID               NULL,
  "QUANTITY_PACKS"                   INTEGER               NOT NULL,
  "QUOTED_UNIT_PRICE"                NUMERIC(18,2)          NOT NULL,
  "CURRENCY"                         CHAR(3)          NOT NULL,
  CONSTRAINT "PK_CART_ITEMS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_CART_ITEMS_1569F899" UNIQUE ("CART_ID", "BRANCH_PRODUCT_ID")
);

-- 09 Inventory lots transfers and reservations

CREATE TABLE "STOCK_RECEIPTS" (
  "ID"                               UUID               NOT NULL,
  "BRANCH_ID"                        UUID               NOT NULL,
  "WAREHOUSE_ID"                     UUID               NOT NULL,
  "SOURCE_REFERENCE"                 VARCHAR(1000)   NULL,
  "RECEIVED_BY"                      UUID               NOT NULL,
  "RECEIVED_AT"                      TIMESTAMPTZ(6)          NOT NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  CONSTRAINT "PK_STOCK_RECEIPTS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_STOCK_RECEIPTS_68B41470" UNIQUE ("WAREHOUSE_ID", "ID")
);

CREATE TABLE "STOCK_RECEIPT_ITEMS" (
  "ID"                               UUID               NOT NULL,
  "WAREHOUSE_ID"                     UUID               NOT NULL,
  "RECEIPT_ID"                       UUID               NOT NULL,
  "LOT_ID"                           UUID               NOT NULL,
  "QUANTITY_PACKS"                   INTEGER               NOT NULL,
  "UNIT_COST"                        NUMERIC(18,2)          NOT NULL,
  CONSTRAINT "PK_STOCK_RECEIPT_ITEMS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_STOCK_RECEIPT_ITE_F6E985E3" UNIQUE ("RECEIPT_ID", "LOT_ID")
);

CREATE TABLE "INVENTORY_LOTS" (
  "ID"                               UUID               NOT NULL,
  "BRANCH_ID"                        UUID               NOT NULL,
  "WAREHOUSE_ID"                     UUID               NOT NULL,
  "PRODUCT_ID"                       UUID               NOT NULL,
  "LOT_CODE"                         VARCHAR(200)    NOT NULL,
  "RECEIVED_ON"                      DATE                  NOT NULL,
  "EXPIRES_ON"                       DATE                  NULL,
  "ON_HAND_PACKS"                    INTEGER               NOT NULL,
  "RESERVED_PACKS"                   INTEGER               NOT NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  CONSTRAINT "PK_INVENTORY_LOTS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_INVENTORY_LOTS_00F3CFE8" UNIQUE ("WAREHOUSE_ID", "PRODUCT_ID", "LOT_CODE"),
  CONSTRAINT "UK_INVENTORY_LOTS_DE53A56B" UNIQUE ("WAREHOUSE_ID", "ID"),
  CONSTRAINT "UK_INVENTORY_LOTS_A4916759" UNIQUE ("WAREHOUSE_ID", "ID", "PRODUCT_ID"),
  CONSTRAINT "UK_INVENTORY_LOTS_F1B41F5C" UNIQUE ("BRANCH_ID", "ID", "PRODUCT_ID")
);

CREATE TABLE "STOCK_TRANSFERS" (
  "ID"                               UUID               NOT NULL,
  "TRANSFER_NO"                      VARCHAR(200)    NOT NULL,
  "FROM_WAREHOUSE_ID"                UUID               NOT NULL,
  "TO_WAREHOUSE_ID"                  UUID               NOT NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  "CREATED_BY"                       UUID               NOT NULL,
  "DISPATCHED_AT"                    TIMESTAMPTZ(6)          NULL,
  "RECEIVED_AT"                      TIMESTAMPTZ(6)          NULL,
  CONSTRAINT "PK_STOCK_TRANSFERS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_STOCK_TRANSFERS_4A25CC5F" UNIQUE ("TRANSFER_NO"),
  CONSTRAINT "UK_STOCK_TRANSFERS_75758661" UNIQUE ("ID", "FROM_WAREHOUSE_ID", "TO_WAREHOUSE_ID")
);

CREATE TABLE "STOCK_TRANSFER_ITEMS" (
  "ID"                               UUID               NOT NULL,
  "TRANSFER_ID"                      UUID               NOT NULL,
  "LINE_NO"                          INTEGER               NOT NULL,
  "FROM_WAREHOUSE_ID"                UUID               NOT NULL,
  "TO_WAREHOUSE_ID"                  UUID               NOT NULL,
  "PRODUCT_ID"                       UUID               NOT NULL,
  "SOURCE_LOT_ID"                    UUID               NOT NULL,
  "DESTINATION_LOT_ID"               UUID               NULL,
  "DISPATCHED_PACKS"                 INTEGER               NOT NULL,
  "RECEIVED_PACKS"                   INTEGER               NOT NULL,
  "DAMAGED_PACKS"                    INTEGER               NOT NULL,
  CONSTRAINT "PK_STOCK_TRANSFER_ITEMS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_STOCK_TRANSFER_IT_DF55DBD7" UNIQUE ("TRANSFER_ID", "LINE_NO")
);

CREATE TABLE "STOCK_RESERVATIONS" (
  "ID"                               UUID               NOT NULL,
  "BRANCH_ID"                        UUID               NOT NULL,
  "PRODUCT_ID"                       UUID               NOT NULL,
  "ORDER_ITEM_ID"                    UUID               NOT NULL,
  "LOT_ID"                           UUID               NOT NULL,
  "QUANTITY_PACKS"                   INTEGER               NOT NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  "EXPIRES_AT"                       TIMESTAMPTZ(6)          NULL,
  "CREATED_AT"                       TIMESTAMPTZ(6)          NOT NULL,
  CONSTRAINT "PK_STOCK_RESERVATIONS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_STOCK_RESERVATION_C08EEC24" UNIQUE ("ORDER_ITEM_ID", "LOT_ID")
);

CREATE TABLE "INVENTORY_MOVEMENTS" (
  "ID"                               UUID               NOT NULL,
  "LOT_ID"                           UUID               NOT NULL,
  "QUANTITY_DELTA"                   INTEGER               NOT NULL,
  "MOVEMENT_TYPE"                    VARCHAR(1000)   NOT NULL,
  "RECEIPT_ITEM_ID"                  UUID               NULL,
  "TRANSFER_ITEM_ID"                 UUID               NULL,
  "RESERVATION_ID"                   UUID               NULL,
  "ADJUSTMENT_REASON"                TEXT                  NULL,
  "ACTOR_USER_ID"                    UUID               NULL,
  "OPERATION_KEY"                    VARCHAR(200)    NOT NULL,
  "OCCURRED_AT"                      TIMESTAMPTZ(6)          NOT NULL,
  CONSTRAINT "PK_INVENTORY_MOVEMENTS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_INVENTORY_MOVEMEN_B65C6740" UNIQUE ("OPERATION_KEY")
);

-- 10 Orders snapshots and change requests

CREATE TABLE "ORDERS" (
  "ID"                               UUID               NOT NULL,
  "ORDER_NO"                         VARCHAR(200)    NOT NULL,
  "CHECKOUT_KEY"                     UUID               NOT NULL,
  "HOUSEHOLD_ID"                     UUID               NOT NULL,
  "BRANCH_ID"                        UUID               NOT NULL,
  "SERVICE_AREA_ID"                  UUID               NOT NULL,
  "ADDRESS_ID"                       UUID               NOT NULL,
  "SOURCE_CART_ID"                   UUID               NULL,
  "DELIVERY_SLOT_ID"                 UUID               NOT NULL,
  "PAYMENT_METHOD_ID"                UUID               NOT NULL,
  "CREATED_BY"                       UUID               NOT NULL,
  "RECIPIENT_NAME_SNAPSHOT"          VARCHAR(1000)   NOT NULL,
  "RECIPIENT_PHONE_SNAPSHOT"         VARCHAR(1000)   NOT NULL,
  "ADDRESS_SNAPSHOT"                 JSONB                  NOT NULL,
  "DELIVERY_SLOT_SNAPSHOT"           JSONB                  NOT NULL,
  "CURRENCY"                         CHAR(3)          NOT NULL,
  "ITEM_SUBTOTAL"                    NUMERIC(18,2)          NOT NULL,
  "DELIVERY_FEE"                     NUMERIC(18,2)          NOT NULL,
  "GRAND_TOTAL"                      NUMERIC(18,2)          NOT NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  "PLACED_AT"                        TIMESTAMPTZ(6)          NOT NULL,
  CONSTRAINT "PK_ORDERS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_ORDERS_C637182A" UNIQUE ("ORDER_NO"),
  CONSTRAINT "UK_ORDERS_5F68BD5F" UNIQUE ("CHECKOUT_KEY"),
  CONSTRAINT "UK_ORDERS_01C49F83" UNIQUE ("SOURCE_CART_ID"),
  CONSTRAINT "UK_ORDERS_CC3401D5" UNIQUE ("BRANCH_ID", "ID"),
  CONSTRAINT "CK_ORDERS_4EC8FB16" CHECK ("ADDRESS_SNAPSHOT" IS JSON),
  CONSTRAINT "CK_ORDERS_F35D6D12" CHECK ("DELIVERY_SLOT_SNAPSHOT" IS JSON)
);

CREATE TABLE "ORDER_ITEMS" (
  "ID"                               UUID               NOT NULL,
  "ORDER_ID"                         UUID               NOT NULL,
  "LINE_NO"                          INTEGER               NOT NULL,
  "BRANCH_ID"                        UUID               NOT NULL,
  "BRANCH_PRODUCT_ID"                UUID               NOT NULL,
  "PRODUCT_ID"                       UUID               NOT NULL,
  "SHOPPING_ITEM_ID"                 UUID               NULL,
  "SKU_SNAPSHOT"                     VARCHAR(1000)   NOT NULL,
  "NAME_SNAPSHOT"                    VARCHAR(1000)   NOT NULL,
  "PACK_QUANTITY_SNAPSHOT"           NUMERIC(18,6)          NOT NULL,
  "PACK_UNIT_CODE_SNAPSHOT"          VARCHAR(1000)   NOT NULL,
  "BASE_QTY_PER_PACK_SNAPSHOT"       NUMERIC(18,6)          NOT NULL,
  "QUANTITY_PACKS"                   INTEGER               NOT NULL,
  "UNIT_PRICE"                       NUMERIC(18,2)          NOT NULL,
  "LINE_TOTAL"                       NUMERIC(18,2)          NOT NULL,
  CONSTRAINT "PK_ORDER_ITEMS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_ORDER_ITEMS_AF0048EA" UNIQUE ("ORDER_ID", "LINE_NO"),
  CONSTRAINT "UK_ORDER_ITEMS_B7C384A4" UNIQUE ("BRANCH_ID", "ID", "PRODUCT_ID")
);

CREATE TABLE "ORDER_CHANGE_REQUESTS" (
  "ID"                               UUID               NOT NULL,
  "ORDER_ID"                         UUID               NOT NULL,
  "REQUEST_TYPE"                     VARCHAR(1000)   NOT NULL,
  "REQUESTED_BY"                     UUID               NOT NULL,
  "REQUESTED_CHANGES"                JSONB                  NOT NULL,
  "REASON"                           TEXT                  NOT NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  "REVIEWED_BY"                      UUID               NULL,
  "REQUESTED_AT"                     TIMESTAMPTZ(6)          NOT NULL,
  "REVIEWED_AT"                      TIMESTAMPTZ(6)          NULL,
  CONSTRAINT "PK_ORDER_CHANGE_REQUESTS" PRIMARY KEY ("ID"),
  CONSTRAINT "CK_ORDER_CHANGE_REQU_D9B90C9E" CHECK ("REQUESTED_CHANGES" IS JSON)
);

CREATE TABLE "ORDER_STATUS_HISTORY" (
  "ID"                               UUID               NOT NULL,
  "ORDER_ID"                         UUID               NOT NULL,
  "FROM_STATUS"                      VARCHAR(1000)   NULL,
  "TO_STATUS"                        VARCHAR(1000)   NOT NULL,
  "CHANGED_BY"                       UUID               NULL,
  "REASON"                           TEXT                  NULL,
  "CHANGED_AT"                       TIMESTAMPTZ(6)          NOT NULL,
  CONSTRAINT "PK_ORDER_STATUS_HISTORY" PRIMARY KEY ("ID")
);

-- 11 Delivery slots runs and attempts

CREATE TABLE "DELIVERY_SLOTS" (
  "ID"                               UUID               NOT NULL,
  "BRANCH_ID"                        UUID               NOT NULL,
  "STARTS_AT"                        TIMESTAMPTZ(6)          NOT NULL,
  "ENDS_AT"                          TIMESTAMPTZ(6)          NOT NULL,
  "CUTOFF_AT"                        TIMESTAMPTZ(6)          NOT NULL,
  "CAPACITY_ORDERS"                  INTEGER               NOT NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  CONSTRAINT "PK_DELIVERY_SLOTS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_DELIVERY_SLOTS_D623D850" UNIQUE ("BRANCH_ID", "STARTS_AT", "ENDS_AT"),
  CONSTRAINT "UK_DELIVERY_SLOTS_34F35A37" UNIQUE ("BRANCH_ID", "ID")
);

CREATE TABLE "DELIVERY_RUNS" (
  "ID"                               UUID               NOT NULL,
  "BRANCH_ID"                        UUID               NOT NULL,
  "DRIVER_USER_ID"                   UUID               NOT NULL,
  "RUN_DATE"                         DATE                  NOT NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  "STARTED_AT"                       TIMESTAMPTZ(6)          NULL,
  "COMPLETED_AT"                     TIMESTAMPTZ(6)          NULL,
  CONSTRAINT "PK_DELIVERY_RUNS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_DELIVERY_RUNS_D4C3432D" UNIQUE ("BRANCH_ID", "ID")
);

CREATE TABLE "DELIVERY_TASKS" (
  "ID"                               UUID               NOT NULL,
  "ORDER_ID"                         UUID               NOT NULL,
  "BRANCH_ID"                        UUID               NOT NULL,
  "RUN_ID"                           UUID               NULL,
  "STOP_SEQUENCE"                    INTEGER               NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  "ASSIGNED_AT"                      TIMESTAMPTZ(6)          NULL,
  "DELIVERED_AT"                     TIMESTAMPTZ(6)          NULL,
  CONSTRAINT "PK_DELIVERY_TASKS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_DELIVERY_TASKS_58A1056C" UNIQUE ("ORDER_ID"),
  CONSTRAINT "UK_DELIVERY_TASKS_82082C31" UNIQUE ("RUN_ID", "STOP_SEQUENCE")
);

CREATE TABLE "DELIVERY_ATTEMPTS" (
  "ID"                               UUID               NOT NULL,
  "DELIVERY_TASK_ID"                 UUID               NOT NULL,
  "ATTEMPT_NO"                       INTEGER               NOT NULL,
  "ATTEMPTED_BY"                     UUID               NOT NULL,
  "ATTEMPTED_AT"                     TIMESTAMPTZ(6)          NOT NULL,
  "RESULT"                           VARCHAR(1000)   NOT NULL,
  "FAILURE_REASON"                   TEXT                  NULL,
  "PROOF_REFERENCE"                  VARCHAR(1000)   NULL,
  CONSTRAINT "PK_DELIVERY_ATTEMPTS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_DELIVERY_ATTEMPTS_B62F58B4" UNIQUE ("DELIVERY_TASK_ID", "ATTEMPT_NO")
);

-- 12 MMQR COD reconciliation and refunds

CREATE TABLE "PAYMENT_METHODS" (
  "ID"                               UUID               NOT NULL,
  "CODE"                             VARCHAR(200)    NOT NULL,
  "NAME"                             VARCHAR(1000)   NOT NULL,
  "IS_ENABLED"                       BOOLEAN           NOT NULL,
  CONSTRAINT "PK_PAYMENT_METHODS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_PAYMENT_METHODS_C13223DD" UNIQUE ("CODE"),
  CONSTRAINT "CK_PAYMENT_METHODS_39BF35F5" CHECK ("IS_ENABLED" IN (FALSE, TRUE))
);

CREATE TABLE "MERCHANT_ACCOUNTS" (
  "ID"                               UUID               NOT NULL,
  "PROVIDER_CODE"                    VARCHAR(200)    NOT NULL,
  "MERCHANT_REFERENCE"               VARCHAR(200)    NOT NULL,
  "OWNER_BRANCH_ID"                  UUID               NULL,
  "DISPLAY_NAME"                     VARCHAR(1000)   NOT NULL,
  "CREDENTIAL_REFERENCE"             VARCHAR(1000)   NOT NULL,
  "IS_ACTIVE"                        BOOLEAN           NOT NULL,
  CONSTRAINT "PK_MERCHANT_ACCOUNTS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_MERCHANT_ACCOUNTS_88471A19" UNIQUE ("PROVIDER_CODE", "MERCHANT_REFERENCE"),
  CONSTRAINT "CK_MERCHANT_ACCOUNTS_2F2CC39E" CHECK ("IS_ACTIVE" IN (FALSE, TRUE))
);

CREATE TABLE "PAYMENTS" (
  "ID"                               UUID               NOT NULL,
  "BRANCH_ID"                        UUID               NOT NULL,
  "ORDER_ID"                         UUID               NOT NULL,
  "PAYMENT_METHOD_ID"                UUID               NOT NULL,
  "MERCHANT_ACCOUNT_ID"              UUID               NULL,
  "ATTEMPT_NO"                       INTEGER               NOT NULL,
  "REQUEST_KEY"                      UUID               NOT NULL,
  "AMOUNT"                           NUMERIC(18,2)          NOT NULL,
  "CURRENCY"                         CHAR(3)          NOT NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  "PROVIDER_TRANSACTION_ID"          VARCHAR(200)    NULL,
  "QR_PAYLOAD_REFERENCE"             VARCHAR(1000)   NULL,
  "EXPIRES_AT"                       TIMESTAMPTZ(6)          NULL,
  "PAID_AT"                          TIMESTAMPTZ(6)          NULL,
  "CREATED_AT"                       TIMESTAMPTZ(6)          NOT NULL,
  CONSTRAINT "PK_PAYMENTS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_PAYMENTS_C61CED38" UNIQUE ("REQUEST_KEY"),
  CONSTRAINT "UK_PAYMENTS_85F37CB7" UNIQUE ("ORDER_ID", "ATTEMPT_NO"),
  CONSTRAINT "UK_PAYMENTS_369D3EEC" UNIQUE ("ORDER_ID", "ID"),
  CONSTRAINT "UK_PAYMENTS_6B87652F" UNIQUE ("BRANCH_ID", "ID"),
  CONSTRAINT "UK_PAYMENTS_AE6280B1" UNIQUE ("MERCHANT_ACCOUNT_ID", "PROVIDER_TRANSACTION_ID")
);

CREATE TABLE "COD_COLLECTIONS" (
  "ID"                               UUID               NOT NULL,
  "BRANCH_ID"                        UUID               NOT NULL,
  "PAYMENT_ID"                       UUID               NOT NULL,
  "DELIVERY_ATTEMPT_ID"              UUID               NOT NULL,
  "COLLECTED_BY"                     UUID               NOT NULL,
  "AMOUNT"                           NUMERIC(18,2)          NOT NULL,
  "COLLECTED_AT"                     TIMESTAMPTZ(6)          NOT NULL,
  "REMITTANCE_ID"                    UUID               NULL,
  CONSTRAINT "PK_COD_COLLECTIONS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_COD_COLLECTIONS_9EEE5028" UNIQUE ("PAYMENT_ID"),
  CONSTRAINT "UK_COD_COLLECTIONS_BE1C1013" UNIQUE ("DELIVERY_ATTEMPT_ID")
);

CREATE TABLE "PAYMENT_EVENTS" (
  "ID"                               UUID               NOT NULL,
  "MERCHANT_ACCOUNT_ID"              UUID               NOT NULL,
  "PAYMENT_ID"                       UUID               NULL,
  "PROVIDER_EVENT_ID"                VARCHAR(200)    NOT NULL,
  "PAYLOAD_HASH"                     VARCHAR(1000)   NOT NULL,
  "SANITIZED_PAYLOAD"                JSONB                  NOT NULL,
  "VERIFICATION_STATUS"              VARCHAR(1000)   NOT NULL,
  "PROCESSING_STATUS"                VARCHAR(1000)   NOT NULL,
  "RECEIVED_AT"                      TIMESTAMPTZ(6)          NOT NULL,
  "PROCESSED_AT"                     TIMESTAMPTZ(6)          NULL,
  CONSTRAINT "PK_PAYMENT_EVENTS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_PAYMENT_EVENTS_26206B9F" UNIQUE ("MERCHANT_ACCOUNT_ID", "PROVIDER_EVENT_ID"),
  CONSTRAINT "CK_PAYMENT_EVENTS_FEB58CAD" CHECK ("SANITIZED_PAYLOAD" IS JSON)
);

CREATE TABLE "REFUNDS" (
  "ID"                               UUID               NOT NULL,
  "ORDER_ID"                         UUID               NOT NULL,
  "PAYMENT_ID"                       UUID               NOT NULL,
  "REQUEST_KEY"                      UUID               NOT NULL,
  "AMOUNT"                           NUMERIC(18,2)          NOT NULL,
  "REFUND_CHANNEL"                   VARCHAR(1000)   NOT NULL,
  "REASON"                           TEXT                  NOT NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  "REQUESTED_BY"                     UUID               NOT NULL,
  "APPROVED_BY"                      UUID               NULL,
  "PROVIDER_REFUND_REFERENCE"        VARCHAR(1000)   NULL,
  "REQUESTED_AT"                     TIMESTAMPTZ(6)          NOT NULL,
  "REFUNDED_AT"                      TIMESTAMPTZ(6)          NULL,
  CONSTRAINT "PK_REFUNDS" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_REFUNDS_770779E9" UNIQUE ("REQUEST_KEY")
);

CREATE TABLE "CASH_REMITTANCES" (
  "ID"                               UUID               NOT NULL,
  "REFERENCE_NO"                     VARCHAR(200)    NOT NULL,
  "BRANCH_ID"                        UUID               NOT NULL,
  "SUBMITTED_BY"                     UUID               NOT NULL,
  "RECEIVED_BY"                      UUID               NULL,
  "DECLARED_AMOUNT"                  NUMERIC(18,2)          NOT NULL,
  "ACCEPTED_AMOUNT"                  NUMERIC(18,2)          NULL,
  "DIFFERENCE_REASON"                TEXT                  NULL,
  "STATUS"                           VARCHAR(1000)   NOT NULL,
  "SUBMITTED_AT"                     TIMESTAMPTZ(6)          NOT NULL,
  "RECEIVED_AT"                      TIMESTAMPTZ(6)          NULL,
  CONSTRAINT "PK_CASH_REMITTANCES" PRIMARY KEY ("ID"),
  CONSTRAINT "UK_CASH_REMITTANCES_CAEA45BC" UNIQUE ("REFERENCE_NO"),
  CONSTRAINT "UK_CASH_REMITTANCES_0B4C43DF" UNIQUE ("BRANCH_ID", "ID")
);


ALTER TABLE "WAREHOUSES" ADD CONSTRAINT "FK_WAREHOUSES_878388C7"
  FOREIGN KEY ("BRANCH_ID")
  REFERENCES "BRANCHES" ("ID");

ALTER TABLE "BRANCH_SERVICE_AREAS" ADD CONSTRAINT "FK_BRANCH_SERVICE_AR_228EFFE7"
  FOREIGN KEY ("BRANCH_ID")
  REFERENCES "BRANCHES" ("ID");

ALTER TABLE "BRANCH_SERVICE_AREAS" ADD CONSTRAINT "FK_BRANCH_SERVICE_AR_FEDB7729"
  FOREIGN KEY ("SERVICE_AREA_ID")
  REFERENCES "SERVICE_AREAS" ("ID");

ALTER TABLE "SERVICE_AREAS" ADD CONSTRAINT "FK_SERVICE_AREAS_04DE9990"
  FOREIGN KEY ("TOWNSHIP_ID")
  REFERENCES "TOWNSHIPS" ("ID");

ALTER TABLE "USER_ROLES" ADD CONSTRAINT "FK_USER_ROLES_ACFE0A1A"
  FOREIGN KEY ("USER_ID")
  REFERENCES "USERS" ("ID");

ALTER TABLE "USER_ROLES" ADD CONSTRAINT "FK_USER_ROLES_7B3AFD2F"
  FOREIGN KEY ("ROLE_ID")
  REFERENCES "ROLES" ("ID");

ALTER TABLE "AUDIT_LOGS" ADD CONSTRAINT "FK_AUDIT_LOGS_5E338349"
  FOREIGN KEY ("ACTOR_USER_ID")
  REFERENCES "USERS" ("ID");

ALTER TABLE "AUDIT_LOGS" ADD CONSTRAINT "FK_AUDIT_LOGS_00C912EE"
  FOREIGN KEY ("BRANCH_ID")
  REFERENCES "BRANCHES" ("ID");

ALTER TABLE "USER_ROLE_BRANCHES" ADD CONSTRAINT "FK_USER_ROLE_BRANCHE_7864874B"
  FOREIGN KEY ("USER_ROLE_ID")
  REFERENCES "USER_ROLES" ("ID");

ALTER TABLE "USER_ROLE_BRANCHES" ADD CONSTRAINT "FK_USER_ROLE_BRANCHE_447C5037"
  FOREIGN KEY ("BRANCH_ID")
  REFERENCES "BRANCHES" ("ID");

ALTER TABLE "ROLE_PERMISSIONS" ADD CONSTRAINT "FK_ROLE_PERMISSIONS_B882B5E9"
  FOREIGN KEY ("ROLE_ID")
  REFERENCES "ROLES" ("ID");

ALTER TABLE "ROLE_PERMISSIONS" ADD CONSTRAINT "FK_ROLE_PERMISSIONS_7FC0ECB0"
  FOREIGN KEY ("PERMISSION_ID")
  REFERENCES "PERMISSIONS" ("ID");

ALTER TABLE "MENUS" ADD CONSTRAINT "FK_MENUS_8C5F47A0"
  FOREIGN KEY ("PARENT_MENU_ID")
  REFERENCES "MENUS" ("ID");

ALTER TABLE "PERMISSIONS" ADD CONSTRAINT "FK_PERMISSIONS_1C93936C"
  FOREIGN KEY ("MENU_ID")
  REFERENCES "MENUS" ("ID");

ALTER TABLE "HOUSEHOLDS" ADD CONSTRAINT "FK_HOUSEHOLDS_379D072B"
  FOREIGN KEY ("OWNER_USER_ID")
  REFERENCES "USERS" ("ID");

ALTER TABLE "HOUSEHOLD_MEMBERS" ADD CONSTRAINT "FK_HOUSEHOLD_MEMBERS_25523AC4"
  FOREIGN KEY ("HOUSEHOLD_ID")
  REFERENCES "HOUSEHOLDS" ("ID");

ALTER TABLE "CUSTOMER_ADDRESSES" ADD CONSTRAINT "FK_CUSTOMER_ADDRESSE_3E4C76AF"
  FOREIGN KEY ("HOUSEHOLD_ID")
  REFERENCES "HOUSEHOLDS" ("ID");

ALTER TABLE "CUSTOMER_ADDRESSES" ADD CONSTRAINT "FK_CUSTOMER_ADDRESSE_D24FD269"
  FOREIGN KEY ("SERVICE_AREA_ID")
  REFERENCES "SERVICE_AREAS" ("ID");

ALTER TABLE "PANTRY_ITEMS" ADD CONSTRAINT "FK_PANTRY_ITEMS_484940DB"
  FOREIGN KEY ("HOUSEHOLD_ID")
  REFERENCES "HOUSEHOLDS" ("ID");

ALTER TABLE "PANTRY_ITEMS" ADD CONSTRAINT "FK_PANTRY_ITEMS_1EE23D8E"
  FOREIGN KEY ("INGREDIENT_ID")
  REFERENCES "INGREDIENTS" ("ID");

ALTER TABLE "MEMBER_ALLERGENS" ADD CONSTRAINT "FK_MEMBER_ALLERGENS_D3730171"
  FOREIGN KEY ("HOUSEHOLD_MEMBER_ID")
  REFERENCES "HOUSEHOLD_MEMBERS" ("ID");

ALTER TABLE "MEMBER_ALLERGENS" ADD CONSTRAINT "FK_MEMBER_ALLERGENS_7B2A0143"
  FOREIGN KEY ("ALLERGEN_ID")
  REFERENCES "ALLERGENS" ("ID");

ALTER TABLE "HOUSEHOLD_INGREDIENT_PREFERENCES" ADD CONSTRAINT "FK_HOUSEHOLD_INGREDI_10DD9DBC"
  FOREIGN KEY ("HOUSEHOLD_ID")
  REFERENCES "HOUSEHOLDS" ("ID");

ALTER TABLE "HOUSEHOLD_INGREDIENT_PREFERENCES" ADD CONSTRAINT "FK_HOUSEHOLD_INGREDI_C176114D"
  FOREIGN KEY ("INGREDIENT_ID")
  REFERENCES "INGREDIENTS" ("ID");

ALTER TABLE "HOUSEHOLD_DIETARY_PROFILES" ADD CONSTRAINT "FK_HOUSEHOLD_DIETARY_02496305"
  FOREIGN KEY ("HOUSEHOLD_ID")
  REFERENCES "HOUSEHOLDS" ("ID");

ALTER TABLE "HOUSEHOLD_DIETARY_PROFILES" ADD CONSTRAINT "FK_HOUSEHOLD_DIETARY_31D72E19"
  FOREIGN KEY ("DIETARY_PROFILE_ID")
  REFERENCES "DIETARY_PROFILES" ("ID");

ALTER TABLE "INGREDIENTS" ADD CONSTRAINT "FK_INGREDIENTS_8FA10287"
  FOREIGN KEY ("BASE_UNIT_ID")
  REFERENCES "UNITS" ("ID");

ALTER TABLE "INGREDIENT_MEASURES" ADD CONSTRAINT "FK_INGREDIENT_MEASUR_B16B10B0"
  FOREIGN KEY ("INGREDIENT_ID")
  REFERENCES "INGREDIENTS" ("ID");

ALTER TABLE "INGREDIENT_MEASURES" ADD CONSTRAINT "FK_INGREDIENT_MEASUR_C2B8D1B0"
  FOREIGN KEY ("UNIT_ID")
  REFERENCES "UNITS" ("ID");

ALTER TABLE "INGREDIENT_ALLERGENS" ADD CONSTRAINT "FK_INGREDIENT_ALLERG_7F33063F"
  FOREIGN KEY ("INGREDIENT_ID")
  REFERENCES "INGREDIENTS" ("ID");

ALTER TABLE "INGREDIENT_ALLERGENS" ADD CONSTRAINT "FK_INGREDIENT_ALLERG_B7B8A965"
  FOREIGN KEY ("ALLERGEN_ID")
  REFERENCES "ALLERGENS" ("ID");

ALTER TABLE "PRODUCTS" ADD CONSTRAINT "FK_PRODUCTS_2BB3CC3B"
  FOREIGN KEY ("INGREDIENT_ID")
  REFERENCES "INGREDIENTS" ("ID");

ALTER TABLE "PRODUCTS" ADD CONSTRAINT "FK_PRODUCTS_5C1098CF"
  FOREIGN KEY ("INGREDIENT_ID", "PACK_UNIT_ID")
  REFERENCES "INGREDIENT_MEASURES" ("INGREDIENT_ID", "UNIT_ID");

ALTER TABLE "BRANCH_PRODUCTS" ADD CONSTRAINT "FK_BRANCH_PRODUCTS_CB4D8391"
  FOREIGN KEY ("BRANCH_ID")
  REFERENCES "BRANCHES" ("ID");

ALTER TABLE "BRANCH_PRODUCTS" ADD CONSTRAINT "FK_BRANCH_PRODUCTS_57BE35F7"
  FOREIGN KEY ("PRODUCT_ID")
  REFERENCES "PRODUCTS" ("ID");

ALTER TABLE "BRANCH_PRICES" ADD CONSTRAINT "FK_BRANCH_PRICES_FB32D090"
  FOREIGN KEY ("BRANCH_PRODUCT_ID")
  REFERENCES "BRANCH_PRODUCTS" ("ID");

ALTER TABLE "BRANCH_PRICES" ADD CONSTRAINT "FK_BRANCH_PRICES_76846C88"
  FOREIGN KEY ("CREATED_BY")
  REFERENCES "USERS" ("ID");

ALTER TABLE "RECIPES" ADD CONSTRAINT "FK_RECIPES_90ACB440"
  FOREIGN KEY ("CREATED_BY")
  REFERENCES "USERS" ("ID");

ALTER TABLE "RECIPE_VERSIONS" ADD CONSTRAINT "FK_RECIPE_VERSIONS_856AEB97"
  FOREIGN KEY ("RECIPE_ID")
  REFERENCES "RECIPES" ("ID");

ALTER TABLE "RECIPE_VERSIONS" ADD CONSTRAINT "FK_RECIPE_VERSIONS_9A436D16"
  FOREIGN KEY ("APPROVED_BY")
  REFERENCES "USERS" ("ID");

ALTER TABLE "RECIPE_INGREDIENTS" ADD CONSTRAINT "FK_RECIPE_INGREDIENT_413FF48A"
  FOREIGN KEY ("RECIPE_VERSION_ID")
  REFERENCES "RECIPE_VERSIONS" ("ID");

ALTER TABLE "RECIPE_INGREDIENTS" ADD CONSTRAINT "FK_RECIPE_INGREDIENT_E7FB02F5"
  FOREIGN KEY ("INGREDIENT_ID", "UNIT_ID")
  REFERENCES "INGREDIENT_MEASURES" ("INGREDIENT_ID", "UNIT_ID");

ALTER TABLE "RECIPE_MEAL_TYPES" ADD CONSTRAINT "FK_RECIPE_MEAL_TYPES_8A842A92"
  FOREIGN KEY ("RECIPE_VERSION_ID")
  REFERENCES "RECIPE_VERSIONS" ("ID");

ALTER TABLE "RECIPE_MEAL_TYPES" ADD CONSTRAINT "FK_RECIPE_MEAL_TYPES_7004A8D9"
  FOREIGN KEY ("MEAL_TYPE_ID")
  REFERENCES "MEAL_TYPES" ("ID");

ALTER TABLE "RECIPE_PAIRINGS" ADD CONSTRAINT "FK_RECIPE_PAIRINGS_707C2824"
  FOREIGN KEY ("RECIPE_VERSION_ID")
  REFERENCES "RECIPE_VERSIONS" ("ID");

ALTER TABLE "RECIPE_PAIRINGS" ADD CONSTRAINT "FK_RECIPE_PAIRINGS_1889E2DA"
  FOREIGN KEY ("COMPANION_VERSION_ID")
  REFERENCES "RECIPE_VERSIONS" ("ID");

ALTER TABLE "NUTRIENTS" ADD CONSTRAINT "FK_NUTRIENTS_F6323B75"
  FOREIGN KEY ("UNIT_ID")
  REFERENCES "UNITS" ("ID");

ALTER TABLE "INGREDIENT_NUTRIENTS" ADD CONSTRAINT "FK_INGREDIENT_NUTRIE_3E22B579"
  FOREIGN KEY ("NUTRIENT_ID")
  REFERENCES "NUTRIENTS" ("ID");

ALTER TABLE "INGREDIENT_NUTRIENTS" ADD CONSTRAINT "FK_INGREDIENT_NUTRIE_BDA9A8F9"
  FOREIGN KEY ("INGREDIENT_ID", "BASIS_UNIT_ID")
  REFERENCES "INGREDIENT_MEASURES" ("INGREDIENT_ID", "UNIT_ID");

ALTER TABLE "DIETARY_PROFILES" ADD CONSTRAINT "FK_DIETARY_PROFILES_F3DEF894"
  FOREIGN KEY ("APPROVED_BY")
  REFERENCES "USERS" ("ID");

ALTER TABLE "PLANNING_RULE_SETS" ADD CONSTRAINT "FK_PLANNING_RULE_SET_B48A1EBD"
  FOREIGN KEY ("APPROVED_BY")
  REFERENCES "USERS" ("ID");

ALTER TABLE "PLANNING_RULES" ADD CONSTRAINT "FK_PLANNING_RULES_B19306F7"
  FOREIGN KEY ("RULE_SET_ID")
  REFERENCES "PLANNING_RULE_SETS" ("ID");

ALTER TABLE "MEAL_PLANS" ADD CONSTRAINT "FK_MEAL_PLANS_907B3E59"
  FOREIGN KEY ("HOUSEHOLD_ID")
  REFERENCES "HOUSEHOLDS" ("ID");

ALTER TABLE "MEAL_PLANS" ADD CONSTRAINT "FK_MEAL_PLANS_0EA48321"
  FOREIGN KEY ("REFERENCE_BRANCH_ID")
  REFERENCES "BRANCHES" ("ID");

ALTER TABLE "MEAL_PLANS" ADD CONSTRAINT "FK_MEAL_PLANS_20850800"
  FOREIGN KEY ("RULE_SET_ID")
  REFERENCES "PLANNING_RULE_SETS" ("ID");

ALTER TABLE "MEAL_SLOTS" ADD CONSTRAINT "FK_MEAL_SLOTS_D71B775E"
  FOREIGN KEY ("MEAL_PLAN_ID")
  REFERENCES "MEAL_PLANS" ("ID");

ALTER TABLE "MEAL_SLOTS" ADD CONSTRAINT "FK_MEAL_SLOTS_3BF7E534"
  FOREIGN KEY ("MEAL_TYPE_ID")
  REFERENCES "MEAL_TYPES" ("ID");

ALTER TABLE "MEAL_SLOT_RECIPES" ADD CONSTRAINT "FK_MEAL_SLOT_RECIPES_21344CEB"
  FOREIGN KEY ("MEAL_SLOT_ID")
  REFERENCES "MEAL_SLOTS" ("ID");

ALTER TABLE "MEAL_SLOT_RECIPES" ADD CONSTRAINT "FK_MEAL_SLOT_RECIPES_24DF4CEE"
  FOREIGN KEY ("RECIPE_VERSION_ID")
  REFERENCES "RECIPE_VERSIONS" ("ID");

ALTER TABLE "SHOPPING_LISTS" ADD CONSTRAINT "FK_SHOPPING_LISTS_F4560CC4"
  FOREIGN KEY ("HOUSEHOLD_ID", "MEAL_PLAN_ID")
  REFERENCES "MEAL_PLANS" ("HOUSEHOLD_ID", "ID");

ALTER TABLE "SHOPPING_ITEMS" ADD CONSTRAINT "FK_SHOPPING_ITEMS_7F6D5C40"
  FOREIGN KEY ("SHOPPING_LIST_ID")
  REFERENCES "SHOPPING_LISTS" ("ID");

ALTER TABLE "SHOPPING_ITEMS" ADD CONSTRAINT "FK_SHOPPING_ITEMS_BF75CD85"
  FOREIGN KEY ("INGREDIENT_ID")
  REFERENCES "INGREDIENTS" ("ID");

ALTER TABLE "MEAL_FEEDBACK" ADD CONSTRAINT "FK_MEAL_FEEDBACK_72234124"
  FOREIGN KEY ("MEAL_SLOT_RECIPE_ID")
  REFERENCES "MEAL_SLOT_RECIPES" ("ID");

ALTER TABLE "MEAL_FEEDBACK" ADD CONSTRAINT "FK_MEAL_FEEDBACK_EF133119"
  FOREIGN KEY ("USER_ID")
  REFERENCES "USERS" ("ID");

ALTER TABLE "CARTS" ADD CONSTRAINT "FK_CARTS_339AD05E"
  FOREIGN KEY ("HOUSEHOLD_ID")
  REFERENCES "HOUSEHOLDS" ("ID");

ALTER TABLE "CARTS" ADD CONSTRAINT "FK_CARTS_A7B70EF3"
  FOREIGN KEY ("BRANCH_ID")
  REFERENCES "BRANCHES" ("ID");

ALTER TABLE "CARTS" ADD CONSTRAINT "FK_CARTS_54B630F8"
  FOREIGN KEY ("HOUSEHOLD_ID", "ADDRESS_ID")
  REFERENCES "CUSTOMER_ADDRESSES" ("HOUSEHOLD_ID", "ID");

ALTER TABLE "CARTS" ADD CONSTRAINT "FK_CARTS_BCBB28A5"
  FOREIGN KEY ("HOUSEHOLD_ID", "SHOPPING_LIST_ID")
  REFERENCES "SHOPPING_LISTS" ("HOUSEHOLD_ID", "ID");

ALTER TABLE "CART_ITEMS" ADD CONSTRAINT "FK_CART_ITEMS_9B38B6D5"
  FOREIGN KEY ("BRANCH_ID", "CART_ID")
  REFERENCES "CARTS" ("BRANCH_ID", "ID");

ALTER TABLE "CART_ITEMS" ADD CONSTRAINT "FK_CART_ITEMS_3D6FFA8B"
  FOREIGN KEY ("BRANCH_ID", "BRANCH_PRODUCT_ID")
  REFERENCES "BRANCH_PRODUCTS" ("BRANCH_ID", "ID");

ALTER TABLE "CART_ITEMS" ADD CONSTRAINT "FK_CART_ITEMS_27A2448C"
  FOREIGN KEY ("SHOPPING_ITEM_ID")
  REFERENCES "SHOPPING_ITEMS" ("ID");

ALTER TABLE "STOCK_RECEIPTS" ADD CONSTRAINT "FK_STOCK_RECEIPTS_467C8CE3"
  FOREIGN KEY ("BRANCH_ID", "WAREHOUSE_ID")
  REFERENCES "WAREHOUSES" ("BRANCH_ID", "ID");

ALTER TABLE "STOCK_RECEIPTS" ADD CONSTRAINT "FK_STOCK_RECEIPTS_6A545396"
  FOREIGN KEY ("RECEIVED_BY")
  REFERENCES "USERS" ("ID");

ALTER TABLE "STOCK_RECEIPT_ITEMS" ADD CONSTRAINT "FK_STOCK_RECEIPT_ITE_190A5B75"
  FOREIGN KEY ("WAREHOUSE_ID", "RECEIPT_ID")
  REFERENCES "STOCK_RECEIPTS" ("WAREHOUSE_ID", "ID");

ALTER TABLE "STOCK_RECEIPT_ITEMS" ADD CONSTRAINT "FK_STOCK_RECEIPT_ITE_4C384D94"
  FOREIGN KEY ("WAREHOUSE_ID", "LOT_ID")
  REFERENCES "INVENTORY_LOTS" ("WAREHOUSE_ID", "ID");

ALTER TABLE "INVENTORY_LOTS" ADD CONSTRAINT "FK_INVENTORY_LOTS_A0B5C46B"
  FOREIGN KEY ("BRANCH_ID", "WAREHOUSE_ID")
  REFERENCES "WAREHOUSES" ("BRANCH_ID", "ID");

ALTER TABLE "INVENTORY_LOTS" ADD CONSTRAINT "FK_INVENTORY_LOTS_9CF31590"
  FOREIGN KEY ("BRANCH_ID", "PRODUCT_ID")
  REFERENCES "BRANCH_PRODUCTS" ("BRANCH_ID", "PRODUCT_ID");

ALTER TABLE "STOCK_TRANSFERS" ADD CONSTRAINT "FK_STOCK_TRANSFERS_F280E35C"
  FOREIGN KEY ("FROM_WAREHOUSE_ID")
  REFERENCES "WAREHOUSES" ("ID");

ALTER TABLE "STOCK_TRANSFERS" ADD CONSTRAINT "FK_STOCK_TRANSFERS_C43546FD"
  FOREIGN KEY ("TO_WAREHOUSE_ID")
  REFERENCES "WAREHOUSES" ("ID");

ALTER TABLE "STOCK_TRANSFERS" ADD CONSTRAINT "FK_STOCK_TRANSFERS_1DCF4E86"
  FOREIGN KEY ("CREATED_BY")
  REFERENCES "USERS" ("ID");

ALTER TABLE "STOCK_TRANSFER_ITEMS" ADD CONSTRAINT "FK_STOCK_TRANSFER_IT_D2D7D96B"
  FOREIGN KEY ("TRANSFER_ID", "FROM_WAREHOUSE_ID", "TO_WAREHOUSE_ID")
  REFERENCES "STOCK_TRANSFERS" ("ID", "FROM_WAREHOUSE_ID", "TO_WAREHOUSE_ID");

ALTER TABLE "STOCK_TRANSFER_ITEMS" ADD CONSTRAINT "FK_STOCK_TRANSFER_IT_82E04711"
  FOREIGN KEY ("FROM_WAREHOUSE_ID", "SOURCE_LOT_ID", "PRODUCT_ID")
  REFERENCES "INVENTORY_LOTS" ("WAREHOUSE_ID", "ID", "PRODUCT_ID");

ALTER TABLE "STOCK_TRANSFER_ITEMS" ADD CONSTRAINT "FK_STOCK_TRANSFER_IT_DA7FB896"
  FOREIGN KEY ("TO_WAREHOUSE_ID", "DESTINATION_LOT_ID", "PRODUCT_ID")
  REFERENCES "INVENTORY_LOTS" ("WAREHOUSE_ID", "ID", "PRODUCT_ID");

ALTER TABLE "STOCK_RESERVATIONS" ADD CONSTRAINT "FK_STOCK_RESERVATION_96D85E98"
  FOREIGN KEY ("BRANCH_ID", "ORDER_ITEM_ID", "PRODUCT_ID")
  REFERENCES "ORDER_ITEMS" ("BRANCH_ID", "ID", "PRODUCT_ID");

ALTER TABLE "STOCK_RESERVATIONS" ADD CONSTRAINT "FK_STOCK_RESERVATION_8F1CD51A"
  FOREIGN KEY ("BRANCH_ID", "LOT_ID", "PRODUCT_ID")
  REFERENCES "INVENTORY_LOTS" ("BRANCH_ID", "ID", "PRODUCT_ID");

ALTER TABLE "INVENTORY_MOVEMENTS" ADD CONSTRAINT "FK_INVENTORY_MOVEMEN_43A705C3"
  FOREIGN KEY ("LOT_ID")
  REFERENCES "INVENTORY_LOTS" ("ID");

ALTER TABLE "INVENTORY_MOVEMENTS" ADD CONSTRAINT "FK_INVENTORY_MOVEMEN_75D74374"
  FOREIGN KEY ("RECEIPT_ITEM_ID")
  REFERENCES "STOCK_RECEIPT_ITEMS" ("ID");

ALTER TABLE "INVENTORY_MOVEMENTS" ADD CONSTRAINT "FK_INVENTORY_MOVEMEN_391A92C1"
  FOREIGN KEY ("TRANSFER_ITEM_ID")
  REFERENCES "STOCK_TRANSFER_ITEMS" ("ID");

ALTER TABLE "INVENTORY_MOVEMENTS" ADD CONSTRAINT "FK_INVENTORY_MOVEMEN_B7680302"
  FOREIGN KEY ("RESERVATION_ID")
  REFERENCES "STOCK_RESERVATIONS" ("ID");

ALTER TABLE "INVENTORY_MOVEMENTS" ADD CONSTRAINT "FK_INVENTORY_MOVEMEN_E95AF65C"
  FOREIGN KEY ("ACTOR_USER_ID")
  REFERENCES "USERS" ("ID");

ALTER TABLE "ORDERS" ADD CONSTRAINT "FK_ORDERS_56D120E1"
  FOREIGN KEY ("HOUSEHOLD_ID")
  REFERENCES "HOUSEHOLDS" ("ID");

ALTER TABLE "ORDERS" ADD CONSTRAINT "FK_ORDERS_1F3F2872"
  FOREIGN KEY ("BRANCH_ID", "SERVICE_AREA_ID")
  REFERENCES "BRANCH_SERVICE_AREAS" ("BRANCH_ID", "SERVICE_AREA_ID");

ALTER TABLE "ORDERS" ADD CONSTRAINT "FK_ORDERS_A1F03677"
  FOREIGN KEY ("HOUSEHOLD_ID", "ADDRESS_ID")
  REFERENCES "CUSTOMER_ADDRESSES" ("HOUSEHOLD_ID", "ID");

ALTER TABLE "ORDERS" ADD CONSTRAINT "FK_ORDERS_051795DD"
  FOREIGN KEY ("BRANCH_ID", "DELIVERY_SLOT_ID")
  REFERENCES "DELIVERY_SLOTS" ("BRANCH_ID", "ID");

ALTER TABLE "ORDERS" ADD CONSTRAINT "FK_ORDERS_83C58045"
  FOREIGN KEY ("BRANCH_ID", "HOUSEHOLD_ID", "SOURCE_CART_ID")
  REFERENCES "CARTS" ("BRANCH_ID", "HOUSEHOLD_ID", "ID");

ALTER TABLE "ORDERS" ADD CONSTRAINT "FK_ORDERS_8FF71387"
  FOREIGN KEY ("PAYMENT_METHOD_ID")
  REFERENCES "PAYMENT_METHODS" ("ID");

ALTER TABLE "ORDERS" ADD CONSTRAINT "FK_ORDERS_AF87AA13"
  FOREIGN KEY ("CREATED_BY")
  REFERENCES "USERS" ("ID");

ALTER TABLE "ORDER_ITEMS" ADD CONSTRAINT "FK_ORDER_ITEMS_4840EEBE"
  FOREIGN KEY ("BRANCH_ID", "ORDER_ID")
  REFERENCES "ORDERS" ("BRANCH_ID", "ID");

ALTER TABLE "ORDER_ITEMS" ADD CONSTRAINT "FK_ORDER_ITEMS_02559EBA"
  FOREIGN KEY ("BRANCH_ID", "BRANCH_PRODUCT_ID", "PRODUCT_ID")
  REFERENCES "BRANCH_PRODUCTS" ("BRANCH_ID", "ID", "PRODUCT_ID");

ALTER TABLE "ORDER_ITEMS" ADD CONSTRAINT "FK_ORDER_ITEMS_1BBEDACA"
  FOREIGN KEY ("SHOPPING_ITEM_ID")
  REFERENCES "SHOPPING_ITEMS" ("ID");

ALTER TABLE "ORDER_CHANGE_REQUESTS" ADD CONSTRAINT "FK_ORDER_CHANGE_REQU_9F455553"
  FOREIGN KEY ("ORDER_ID")
  REFERENCES "ORDERS" ("ID");

ALTER TABLE "ORDER_CHANGE_REQUESTS" ADD CONSTRAINT "FK_ORDER_CHANGE_REQU_A06B248F"
  FOREIGN KEY ("REQUESTED_BY")
  REFERENCES "USERS" ("ID");

ALTER TABLE "ORDER_CHANGE_REQUESTS" ADD CONSTRAINT "FK_ORDER_CHANGE_REQU_F21B7345"
  FOREIGN KEY ("REVIEWED_BY")
  REFERENCES "USERS" ("ID");

ALTER TABLE "ORDER_STATUS_HISTORY" ADD CONSTRAINT "FK_ORDER_STATUS_HIST_3BDE5193"
  FOREIGN KEY ("ORDER_ID")
  REFERENCES "ORDERS" ("ID");

ALTER TABLE "ORDER_STATUS_HISTORY" ADD CONSTRAINT "FK_ORDER_STATUS_HIST_365CC028"
  FOREIGN KEY ("CHANGED_BY")
  REFERENCES "USERS" ("ID");

ALTER TABLE "DELIVERY_SLOTS" ADD CONSTRAINT "FK_DELIVERY_SLOTS_F70588BC"
  FOREIGN KEY ("BRANCH_ID")
  REFERENCES "BRANCHES" ("ID");

ALTER TABLE "DELIVERY_RUNS" ADD CONSTRAINT "FK_DELIVERY_RUNS_2EDBAF0F"
  FOREIGN KEY ("BRANCH_ID")
  REFERENCES "BRANCHES" ("ID");

ALTER TABLE "DELIVERY_RUNS" ADD CONSTRAINT "FK_DELIVERY_RUNS_9EC25973"
  FOREIGN KEY ("DRIVER_USER_ID")
  REFERENCES "USERS" ("ID");

ALTER TABLE "DELIVERY_TASKS" ADD CONSTRAINT "FK_DELIVERY_TASKS_776C13B7"
  FOREIGN KEY ("BRANCH_ID", "ORDER_ID")
  REFERENCES "ORDERS" ("BRANCH_ID", "ID");

ALTER TABLE "DELIVERY_TASKS" ADD CONSTRAINT "FK_DELIVERY_TASKS_9D168F1F"
  FOREIGN KEY ("BRANCH_ID", "RUN_ID")
  REFERENCES "DELIVERY_RUNS" ("BRANCH_ID", "ID");

ALTER TABLE "DELIVERY_ATTEMPTS" ADD CONSTRAINT "FK_DELIVERY_ATTEMPTS_326BE9CD"
  FOREIGN KEY ("DELIVERY_TASK_ID")
  REFERENCES "DELIVERY_TASKS" ("ID");

ALTER TABLE "DELIVERY_ATTEMPTS" ADD CONSTRAINT "FK_DELIVERY_ATTEMPTS_EB17B699"
  FOREIGN KEY ("ATTEMPTED_BY")
  REFERENCES "USERS" ("ID");

ALTER TABLE "MERCHANT_ACCOUNTS" ADD CONSTRAINT "FK_MERCHANT_ACCOUNTS_484BF7C4"
  FOREIGN KEY ("OWNER_BRANCH_ID")
  REFERENCES "BRANCHES" ("ID");

ALTER TABLE "PAYMENTS" ADD CONSTRAINT "FK_PAYMENTS_3B196C4C"
  FOREIGN KEY ("BRANCH_ID", "ORDER_ID")
  REFERENCES "ORDERS" ("BRANCH_ID", "ID");

ALTER TABLE "PAYMENTS" ADD CONSTRAINT "FK_PAYMENTS_25A61B01"
  FOREIGN KEY ("PAYMENT_METHOD_ID")
  REFERENCES "PAYMENT_METHODS" ("ID");

ALTER TABLE "PAYMENTS" ADD CONSTRAINT "FK_PAYMENTS_F2F10A3A"
  FOREIGN KEY ("MERCHANT_ACCOUNT_ID")
  REFERENCES "MERCHANT_ACCOUNTS" ("ID");

ALTER TABLE "COD_COLLECTIONS" ADD CONSTRAINT "FK_COD_COLLECTIONS_207CD8EA"
  FOREIGN KEY ("BRANCH_ID", "PAYMENT_ID")
  REFERENCES "PAYMENTS" ("BRANCH_ID", "ID");

ALTER TABLE "COD_COLLECTIONS" ADD CONSTRAINT "FK_COD_COLLECTIONS_745BB73B"
  FOREIGN KEY ("DELIVERY_ATTEMPT_ID")
  REFERENCES "DELIVERY_ATTEMPTS" ("ID");

ALTER TABLE "COD_COLLECTIONS" ADD CONSTRAINT "FK_COD_COLLECTIONS_D83D016E"
  FOREIGN KEY ("COLLECTED_BY")
  REFERENCES "USERS" ("ID");

ALTER TABLE "COD_COLLECTIONS" ADD CONSTRAINT "FK_COD_COLLECTIONS_A1286E4C"
  FOREIGN KEY ("BRANCH_ID", "REMITTANCE_ID")
  REFERENCES "CASH_REMITTANCES" ("BRANCH_ID", "ID");

ALTER TABLE "PAYMENT_EVENTS" ADD CONSTRAINT "FK_PAYMENT_EVENTS_412EC05F"
  FOREIGN KEY ("MERCHANT_ACCOUNT_ID")
  REFERENCES "MERCHANT_ACCOUNTS" ("ID");

ALTER TABLE "PAYMENT_EVENTS" ADD CONSTRAINT "FK_PAYMENT_EVENTS_723C843F"
  FOREIGN KEY ("PAYMENT_ID")
  REFERENCES "PAYMENTS" ("ID");

ALTER TABLE "REFUNDS" ADD CONSTRAINT "FK_REFUNDS_CD75A26A"
  FOREIGN KEY ("ORDER_ID", "PAYMENT_ID")
  REFERENCES "PAYMENTS" ("ORDER_ID", "ID");

ALTER TABLE "REFUNDS" ADD CONSTRAINT "FK_REFUNDS_631BDE5C"
  FOREIGN KEY ("REQUESTED_BY")
  REFERENCES "USERS" ("ID");

ALTER TABLE "REFUNDS" ADD CONSTRAINT "FK_REFUNDS_A2635B56"
  FOREIGN KEY ("APPROVED_BY")
  REFERENCES "USERS" ("ID");

ALTER TABLE "CASH_REMITTANCES" ADD CONSTRAINT "FK_CASH_REMITTANCES_A8936B7F"
  FOREIGN KEY ("BRANCH_ID")
  REFERENCES "BRANCHES" ("ID");

ALTER TABLE "CASH_REMITTANCES" ADD CONSTRAINT "FK_CASH_REMITTANCES_203EDCFB"
  FOREIGN KEY ("SUBMITTED_BY")
  REFERENCES "USERS" ("ID");

ALTER TABLE "CASH_REMITTANCES" ADD CONSTRAINT "FK_CASH_REMITTANCES_08DE3E38"
  FOREIGN KEY ("RECEIVED_BY")
  REFERENCES "USERS" ("ID");

COMMIT;
