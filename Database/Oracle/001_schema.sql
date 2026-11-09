-- Meal planner schema: all 69 tables from the supplied database specification.
-- Target: Oracle Database 19c, COMPATIBLE >= 12.2 (some source names exceed 30 bytes).
-- Preserves NOT NULL / UNIQUE identifiers. NO PRIMARY KEYS are declared in the source.
-- UUID = RAW(16); applications supply IDs (no generated defaults were specified).
-- Text length assumptions: indexed/key text 200 CHAR; ordinary text 1000 CHAR;
-- narrative text and JSON use CLOB. Review these choices before deployment.
-- Review partially NULL composite unique keys in PAYMENTS and DELIVERY_TASKS;
-- Oracle still enforces uniqueness of the remaining non-NULL key values.
-- JSON checks use Oracle 19c IS JSON STRICT (objects/arrays).
-- Uppercase quoted names protect reserved names such as MEAL_FEEDBACK."COMMENT".
-- Run in a new application schema with CREATE TABLE and tablespace quota.
-- DDL commits implicitly. On error, earlier successful DDL remains applied.

SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

PROMPT Creating tables and unique constraints...

-- 02 Branches and coverage

CREATE TABLE "BRANCHES" (
  "ID"                               RAW(16)               NOT NULL,
  "CODE"                             VARCHAR2(200 CHAR)    NOT NULL,
  "NAME"                             VARCHAR2(1000 CHAR)   NOT NULL,
  "ADDRESS_TEXT"                     CLOB                  NOT NULL,
  "PHONE"                            VARCHAR2(1000 CHAR)   NOT NULL,
  "TIME_ZONE"                        VARCHAR2(1000 CHAR)   NOT NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  "CREATED_AT"                       TIMESTAMP(6)          NOT NULL,
  CONSTRAINT "UK_BRANCHES_42692170" UNIQUE ("ID"),
  CONSTRAINT "UK_BRANCHES_B75F9A51" UNIQUE ("CODE"),
  CONSTRAINT "CK_BRANCHES_8DFA468F" CHECK ("IS_ACTIVE" IN (0, 1))
);

CREATE TABLE "WAREHOUSES" (
  "ID"                               RAW(16)               NOT NULL,
  "BRANCH_ID"                        RAW(16)               NOT NULL,
  "CODE"                             VARCHAR2(200 CHAR)    NOT NULL,
  "NAME"                             VARCHAR2(1000 CHAR)   NOT NULL,
  "ADDRESS_TEXT"                     CLOB                  NOT NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  CONSTRAINT "UK_WAREHOUSES_8D1F421E" UNIQUE ("ID"),
  CONSTRAINT "UK_WAREHOUSES_8DFBEB63" UNIQUE ("BRANCH_ID", "CODE"),
  CONSTRAINT "UK_WAREHOUSES_E328968D" UNIQUE ("BRANCH_ID", "ID"),
  CONSTRAINT "CK_WAREHOUSES_7CA73072" CHECK ("IS_ACTIVE" IN (0, 1))
);

CREATE TABLE "TOWNSHIPS" (
  "ID"                               RAW(16)               NOT NULL,
  "CODE"                             VARCHAR2(200 CHAR)    NOT NULL,
  "NAME_MM"                          VARCHAR2(1000 CHAR)   NOT NULL,
  "NAME_EN"                          VARCHAR2(1000 CHAR)   NULL,
  "REGION_NAME"                      VARCHAR2(1000 CHAR)   NOT NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  CONSTRAINT "UK_TOWNSHIPS_0C9F64D0" UNIQUE ("ID"),
  CONSTRAINT "UK_TOWNSHIPS_EEAAB3DF" UNIQUE ("CODE"),
  CONSTRAINT "CK_TOWNSHIPS_88466DCC" CHECK ("IS_ACTIVE" IN (0, 1))
);

CREATE TABLE "BRANCH_SERVICE_AREAS" (
  "ID"                               RAW(16)               NOT NULL,
  "BRANCH_ID"                        RAW(16)               NOT NULL,
  "SERVICE_AREA_ID"                  RAW(16)               NOT NULL,
  "PRIORITY_RANK"                    INTEGER               NOT NULL,
  "DELIVERY_FEE"                     NUMBER(18,2)          NOT NULL,
  "MINIMUM_ORDER"                    NUMBER(18,2)          NOT NULL,
  "CURRENCY"                         CHAR(3 CHAR)          NOT NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  CONSTRAINT "UK_BRANCH_SERVICE_AR_84381F55" UNIQUE ("ID"),
  CONSTRAINT "UK_BRANCH_SERVICE_AR_D143E7D9" UNIQUE ("BRANCH_ID", "SERVICE_AREA_ID"),
  CONSTRAINT "UK_BRANCH_SERVICE_AR_95EE407F" UNIQUE ("SERVICE_AREA_ID", "PRIORITY_RANK"),
  CONSTRAINT "CK_BRANCH_SERVICE_AR_53DF297B" CHECK ("IS_ACTIVE" IN (0, 1))
);

CREATE TABLE "SERVICE_AREAS" (
  "ID"                               RAW(16)               NOT NULL,
  "TOWNSHIP_ID"                      RAW(16)               NOT NULL,
  "CODE"                             VARCHAR2(200 CHAR)    NOT NULL,
  "NAME"                             VARCHAR2(1000 CHAR)   NOT NULL,
  "BOUNDARY_GEOJSON"                 CLOB                  NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  CONSTRAINT "UK_SERVICE_AREAS_538E568E" UNIQUE ("ID"),
  CONSTRAINT "UK_SERVICE_AREAS_7DDB18E4" UNIQUE ("TOWNSHIP_ID", "CODE"),
  CONSTRAINT "CK_SERVICE_AREAS_BD13EFB0" CHECK ("BOUNDARY_GEOJSON" IS JSON STRICT),
  CONSTRAINT "CK_SERVICE_AREAS_FF414BB6" CHECK ("IS_ACTIVE" IN (0, 1))
);

-- 03 Identity roles and permissions

CREATE TABLE "USERS" (
  "ID"                               RAW(16)               NOT NULL,
  "PHONE"                            VARCHAR2(200 CHAR)    NOT NULL,
  "DISPLAY_NAME"                     VARCHAR2(1000 CHAR)   NOT NULL,
  "EMAIL"                            VARCHAR2(1000 CHAR)   NULL,
  "PASSWORD_HASH"                    VARCHAR2(1000 CHAR)   NULL,
  "ACCOUNT_STATUS"                   VARCHAR2(1000 CHAR)   NOT NULL,
  "PHONE_VERIFIED_AT"                TIMESTAMP(6)          NULL,
  "CREATED_AT"                       TIMESTAMP(6)          NOT NULL,
  CONSTRAINT "UK_USERS_7F0BABC0" UNIQUE ("ID"),
  CONSTRAINT "UK_USERS_9D2EA286" UNIQUE ("PHONE")
);

CREATE TABLE "USER_ROLES" (
  "ID"                               RAW(16)               NOT NULL,
  "USER_ID"                          RAW(16)               NOT NULL,
  "ROLE_ID"                          RAW(16)               NOT NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  CONSTRAINT "UK_USER_ROLES_9C392204" UNIQUE ("ID"),
  CONSTRAINT "UK_USER_ROLES_56F7B8FF" UNIQUE ("USER_ID", "ROLE_ID"),
  CONSTRAINT "CK_USER_ROLES_EC2D778C" CHECK ("IS_ACTIVE" IN (0, 1))
);

CREATE TABLE "ROLES" (
  "ID"                               RAW(16)               NOT NULL,
  "CODE"                             VARCHAR2(200 CHAR)    NOT NULL,
  "NAME"                             VARCHAR2(1000 CHAR)   NOT NULL,
  "SCOPE_MODE"                       VARCHAR2(1000 CHAR)   NOT NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  CONSTRAINT "UK_ROLES_AC2DF6D1" UNIQUE ("ID"),
  CONSTRAINT "UK_ROLES_FA2A4F1E" UNIQUE ("CODE"),
  CONSTRAINT "CK_ROLES_A8DFF63C" CHECK ("IS_ACTIVE" IN (0, 1))
);

CREATE TABLE "AUDIT_LOGS" (
  "ID"                               RAW(16)               NOT NULL,
  "ACTOR_USER_ID"                    RAW(16)               NULL,
  "BRANCH_ID"                        RAW(16)               NULL,
  "ACTION_CODE"                      VARCHAR2(1000 CHAR)   NOT NULL,
  "ENTITY_TYPE"                      VARCHAR2(1000 CHAR)   NOT NULL,
  "ENTITY_IDENTIFIER"                VARCHAR2(1000 CHAR)   NOT NULL,
  "BEFORE_JSON"                      CLOB                  NULL,
  "AFTER_JSON"                       CLOB                  NULL,
  "REQUEST_ID"                       VARCHAR2(1000 CHAR)   NULL,
  "OCCURRED_AT"                      TIMESTAMP(6)          NOT NULL,
  CONSTRAINT "UK_AUDIT_LOGS_4988C3ED" UNIQUE ("ID"),
  CONSTRAINT "CK_AUDIT_LOGS_AF5A7DDC" CHECK ("BEFORE_JSON" IS JSON STRICT),
  CONSTRAINT "CK_AUDIT_LOGS_71748B06" CHECK ("AFTER_JSON" IS JSON STRICT)
);

CREATE TABLE "USER_ROLE_BRANCHES" (
  "ID"                               RAW(16)               NOT NULL,
  "USER_ROLE_ID"                     RAW(16)               NOT NULL,
  "BRANCH_ID"                        RAW(16)               NOT NULL,
  CONSTRAINT "UK_USER_ROLE_BRANCHE_462684A2" UNIQUE ("ID"),
  CONSTRAINT "UK_USER_ROLE_BRANCHE_11D261C7" UNIQUE ("USER_ROLE_ID", "BRANCH_ID")
);

CREATE TABLE "ROLE_PERMISSIONS" (
  "ID"                               RAW(16)               NOT NULL,
  "ROLE_ID"                          RAW(16)               NOT NULL,
  "PERMISSION_ID"                    RAW(16)               NOT NULL,
  CONSTRAINT "UK_ROLE_PERMISSIONS_B88D4E0A" UNIQUE ("ID"),
  CONSTRAINT "UK_ROLE_PERMISSIONS_3F414C67" UNIQUE ("ROLE_ID", "PERMISSION_ID")
);

CREATE TABLE "MENUS" (
  "ID"                               RAW(16)               NOT NULL,
  "PARENT_MENU_ID"                   RAW(16)               NULL,
  "CODE"                             VARCHAR2(200 CHAR)    NOT NULL,
  "LABEL"                            VARCHAR2(1000 CHAR)   NOT NULL,
  "ROUTE"                            VARCHAR2(1000 CHAR)   NULL,
  "SORT_ORDER"                       INTEGER               NOT NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  CONSTRAINT "UK_MENUS_DAFE8605" UNIQUE ("ID"),
  CONSTRAINT "UK_MENUS_253D8C2A" UNIQUE ("CODE"),
  CONSTRAINT "CK_MENUS_5F58C976" CHECK ("IS_ACTIVE" IN (0, 1))
);

CREATE TABLE "PERMISSIONS" (
  "ID"                               RAW(16)               NOT NULL,
  "MENU_ID"                          RAW(16)               NOT NULL,
  "ACTION_CODE"                      VARCHAR2(200 CHAR)    NOT NULL,
  "DESCRIPTION"                      CLOB                  NOT NULL,
  CONSTRAINT "UK_PERMISSIONS_86496098" UNIQUE ("ID"),
  CONSTRAINT "UK_PERMISSIONS_23C6F1B6" UNIQUE ("MENU_ID", "ACTION_CODE")
);

-- 04 Households preferences and pantry

CREATE TABLE "HOUSEHOLDS" (
  "ID"                               RAW(16)               NOT NULL,
  "OWNER_USER_ID"                    RAW(16)               NOT NULL,
  "NAME"                             VARCHAR2(1000 CHAR)   NOT NULL,
  "WEEKLY_BUDGET"                    NUMBER(18,2)          NULL,
  "CURRENCY"                         CHAR(3 CHAR)          NOT NULL,
  "MAX_COOKING_MINUTES"              INTEGER               NULL,
  "CREATED_AT"                       TIMESTAMP(6)          NOT NULL,
  CONSTRAINT "UK_HOUSEHOLDS_E15938D5" UNIQUE ("ID")
);

CREATE TABLE "HOUSEHOLD_MEMBERS" (
  "ID"                               RAW(16)               NOT NULL,
  "HOUSEHOLD_ID"                     RAW(16)               NOT NULL,
  "DISPLAY_NAME"                     VARCHAR2(1000 CHAR)   NOT NULL,
  "AGE_GROUP"                        VARCHAR2(1000 CHAR)   NOT NULL,
  "SERVING_FACTOR"                   NUMBER(18,6)          NOT NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  CONSTRAINT "UK_HOUSEHOLD_MEMBERS_42F1EB4D" UNIQUE ("ID"),
  CONSTRAINT "CK_HOUSEHOLD_MEMBERS_EC4B6024" CHECK ("IS_ACTIVE" IN (0, 1))
);

CREATE TABLE "CUSTOMER_ADDRESSES" (
  "ID"                               RAW(16)               NOT NULL,
  "HOUSEHOLD_ID"                     RAW(16)               NOT NULL,
  "SERVICE_AREA_ID"                  RAW(16)               NOT NULL,
  "RECIPIENT_NAME"                   VARCHAR2(1000 CHAR)   NOT NULL,
  "RECIPIENT_PHONE"                  VARCHAR2(1000 CHAR)   NOT NULL,
  "ADDRESS_TEXT"                     CLOB                  NOT NULL,
  "LATITUDE"                         NUMBER(10,7)          NULL,
  "LONGITUDE"                        NUMBER(10,7)          NULL,
  "DELIVERY_INSTRUCTIONS"            CLOB                  NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  CONSTRAINT "UK_CUSTOMER_ADDRESSE_E48D21BE" UNIQUE ("ID"),
  CONSTRAINT "UK_CUSTOMER_ADDRESSE_A903CEFC" UNIQUE ("HOUSEHOLD_ID", "ID"),
  CONSTRAINT "CK_CUSTOMER_ADDRESSE_60A793E0" CHECK ("IS_ACTIVE" IN (0, 1))
);

CREATE TABLE "PANTRY_ITEMS" (
  "ID"                               RAW(16)               NOT NULL,
  "HOUSEHOLD_ID"                     RAW(16)               NOT NULL,
  "INGREDIENT_ID"                    RAW(16)               NOT NULL,
  "QUANTITY_BASE"                    NUMBER(18,6)          NOT NULL,
  "UPDATED_AT"                       TIMESTAMP(6)          NOT NULL,
  CONSTRAINT "UK_PANTRY_ITEMS_C30B330D" UNIQUE ("ID"),
  CONSTRAINT "UK_PANTRY_ITEMS_499A8935" UNIQUE ("HOUSEHOLD_ID", "INGREDIENT_ID")
);

CREATE TABLE "MEMBER_ALLERGENS" (
  "ID"                               RAW(16)               NOT NULL,
  "HOUSEHOLD_MEMBER_ID"              RAW(16)               NOT NULL,
  "ALLERGEN_ID"                      RAW(16)               NOT NULL,
  "NOTES"                            CLOB                  NULL,
  CONSTRAINT "UK_MEMBER_ALLERGENS_99BEF1B1" UNIQUE ("ID"),
  CONSTRAINT "UK_MEMBER_ALLERGENS_BBFAD81F" UNIQUE ("HOUSEHOLD_MEMBER_ID", "ALLERGEN_ID")
);

CREATE TABLE "HOUSEHOLD_INGREDIENT_PREFERENCES" (
  "ID"                               RAW(16)               NOT NULL,
  "HOUSEHOLD_ID"                     RAW(16)               NOT NULL,
  "INGREDIENT_ID"                    RAW(16)               NOT NULL,
  "PREFERENCE"                       VARCHAR2(1000 CHAR)   NOT NULL,
  CONSTRAINT "UK_HOUSEHOLD_INGREDI_ECBA9026" UNIQUE ("ID"),
  CONSTRAINT "UK_HOUSEHOLD_INGREDI_C4B488AF" UNIQUE ("HOUSEHOLD_ID", "INGREDIENT_ID")
);

CREATE TABLE "HOUSEHOLD_DIETARY_PROFILES" (
  "ID"                               RAW(16)               NOT NULL,
  "HOUSEHOLD_ID"                     RAW(16)               NOT NULL,
  "DIETARY_PROFILE_ID"               RAW(16)               NOT NULL,
  CONSTRAINT "UK_HOUSEHOLD_DIETARY_9AAC0498" UNIQUE ("ID"),
  CONSTRAINT "UK_HOUSEHOLD_DIETARY_123701BC" UNIQUE ("HOUSEHOLD_ID", "DIETARY_PROFILE_ID")
);

-- 05 Ingredients products and branch prices

CREATE TABLE "UNITS" (
  "ID"                               RAW(16)               NOT NULL,
  "CODE"                             VARCHAR2(200 CHAR)    NOT NULL,
  "NAME_MM"                          VARCHAR2(1000 CHAR)   NOT NULL,
  "DIMENSION"                        VARCHAR2(1000 CHAR)   NOT NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  CONSTRAINT "UK_UNITS_4532C9C6" UNIQUE ("ID"),
  CONSTRAINT "UK_UNITS_79964A78" UNIQUE ("CODE"),
  CONSTRAINT "CK_UNITS_1F1E0A26" CHECK ("IS_ACTIVE" IN (0, 1))
);

CREATE TABLE "INGREDIENTS" (
  "ID"                               RAW(16)               NOT NULL,
  "CODE"                             VARCHAR2(200 CHAR)    NOT NULL,
  "NAME_MM"                          VARCHAR2(1000 CHAR)   NOT NULL,
  "CATEGORY_CODE"                    VARCHAR2(1000 CHAR)   NOT NULL,
  "FOOD_GROUP_CODE"                  VARCHAR2(1000 CHAR)   NOT NULL,
  "BASE_UNIT_ID"                     RAW(16)               NOT NULL,
  "STORAGE_GUIDANCE"                 CLOB                  NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  CONSTRAINT "UK_INGREDIENTS_55FC4ECF" UNIQUE ("ID"),
  CONSTRAINT "UK_INGREDIENTS_679F2E6D" UNIQUE ("CODE"),
  CONSTRAINT "CK_INGREDIENTS_6F64B105" CHECK ("IS_ACTIVE" IN (0, 1))
);

CREATE TABLE "INGREDIENT_MEASURES" (
  "ID"                               RAW(16)               NOT NULL,
  "INGREDIENT_ID"                    RAW(16)               NOT NULL,
  "UNIT_ID"                          RAW(16)               NOT NULL,
  "BASE_QUANTITY"                    NUMBER(18,6)          NOT NULL,
  "SOURCE_NOTE"                      CLOB                  NULL,
  CONSTRAINT "UK_INGREDIENT_MEASUR_AB4607A9" UNIQUE ("ID"),
  CONSTRAINT "UK_INGREDIENT_MEASUR_70214E1D" UNIQUE ("INGREDIENT_ID", "UNIT_ID")
);

CREATE TABLE "ALLERGENS" (
  "ID"                               RAW(16)               NOT NULL,
  "CODE"                             VARCHAR2(200 CHAR)    NOT NULL,
  "NAME"                             VARCHAR2(1000 CHAR)   NOT NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  CONSTRAINT "UK_ALLERGENS_B7AEA717" UNIQUE ("ID"),
  CONSTRAINT "UK_ALLERGENS_09C53D67" UNIQUE ("CODE"),
  CONSTRAINT "CK_ALLERGENS_DDAFCF59" CHECK ("IS_ACTIVE" IN (0, 1))
);

CREATE TABLE "INGREDIENT_ALLERGENS" (
  "ID"                               RAW(16)               NOT NULL,
  "INGREDIENT_ID"                    RAW(16)               NOT NULL,
  "ALLERGEN_ID"                      RAW(16)               NOT NULL,
  CONSTRAINT "UK_INGREDIENT_ALLERG_425EAE9A" UNIQUE ("ID"),
  CONSTRAINT "UK_INGREDIENT_ALLERG_62388CCB" UNIQUE ("INGREDIENT_ID", "ALLERGEN_ID")
);

CREATE TABLE "PRODUCTS" (
  "ID"                               RAW(16)               NOT NULL,
  "SKU"                              VARCHAR2(200 CHAR)    NOT NULL,
  "INGREDIENT_ID"                    RAW(16)               NOT NULL,
  "NAME"                             VARCHAR2(1000 CHAR)   NOT NULL,
  "PACK_QUANTITY"                    NUMBER(18,6)          NOT NULL,
  "PACK_UNIT_ID"                     RAW(16)               NOT NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  CONSTRAINT "UK_PRODUCTS_F59D468E" UNIQUE ("ID"),
  CONSTRAINT "UK_PRODUCTS_10B4531D" UNIQUE ("SKU"),
  CONSTRAINT "CK_PRODUCTS_5E2A6390" CHECK ("IS_ACTIVE" IN (0, 1))
);

CREATE TABLE "BRANCH_PRODUCTS" (
  "ID"                               RAW(16)               NOT NULL,
  "BRANCH_ID"                        RAW(16)               NOT NULL,
  "PRODUCT_ID"                       RAW(16)               NOT NULL,
  "IS_AVAILABLE"                     NUMBER(1,0)           NOT NULL,
  "REORDER_LEVEL_PACKS"              INTEGER               NOT NULL,
  CONSTRAINT "UK_BRANCH_PRODUCTS_9EA1E37F" UNIQUE ("ID"),
  CONSTRAINT "UK_BRANCH_PRODUCTS_C37DAF9A" UNIQUE ("BRANCH_ID", "PRODUCT_ID"),
  CONSTRAINT "UK_BRANCH_PRODUCTS_ACA6D5E4" UNIQUE ("BRANCH_ID", "ID"),
  CONSTRAINT "UK_BRANCH_PRODUCTS_752344BE" UNIQUE ("BRANCH_ID", "ID", "PRODUCT_ID"),
  CONSTRAINT "CK_BRANCH_PRODUCTS_B6CBA6CE" CHECK ("IS_AVAILABLE" IN (0, 1))
);

CREATE TABLE "BRANCH_PRICES" (
  "ID"                               RAW(16)               NOT NULL,
  "BRANCH_PRODUCT_ID"                RAW(16)               NOT NULL,
  "UNIT_PRICE"                       NUMBER(18,2)          NOT NULL,
  "CURRENCY"                         CHAR(3 CHAR)          NOT NULL,
  "VALID_FROM"                       TIMESTAMP(6)          NOT NULL,
  "VALID_TO"                         TIMESTAMP(6)          NULL,
  "CREATED_BY"                       RAW(16)               NOT NULL,
  CONSTRAINT "UK_BRANCH_PRICES_E2E7904B" UNIQUE ("ID"),
  CONSTRAINT "UK_BRANCH_PRICES_D90BCF0D" UNIQUE ("BRANCH_PRODUCT_ID", "VALID_FROM")
);

-- 06 Recipes meal types and pairing

CREATE TABLE "RECIPES" (
  "ID"                               RAW(16)               NOT NULL,
  "CODE"                             VARCHAR2(200 CHAR)    NOT NULL,
  "CATEGORY_CODE"                    VARCHAR2(1000 CHAR)   NOT NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  "CREATED_BY"                       RAW(16)               NOT NULL,
  "CREATED_AT"                       TIMESTAMP(6)          NOT NULL,
  CONSTRAINT "UK_RECIPES_88D1F482" UNIQUE ("ID"),
  CONSTRAINT "UK_RECIPES_DDFD6603" UNIQUE ("CODE"),
  CONSTRAINT "CK_RECIPES_AD9E4DDC" CHECK ("IS_ACTIVE" IN (0, 1))
);

CREATE TABLE "RECIPE_VERSIONS" (
  "ID"                               RAW(16)               NOT NULL,
  "RECIPE_ID"                        RAW(16)               NOT NULL,
  "VERSION_NO"                       INTEGER               NOT NULL,
  "TITLE_MM"                         VARCHAR2(1000 CHAR)   NOT NULL,
  "BASE_SERVINGS"                    NUMBER(18,6)          NOT NULL,
  "PREP_MINUTES"                     INTEGER               NOT NULL,
  "COOK_MINUTES"                     INTEGER               NOT NULL,
  "INSTRUCTIONS"                     CLOB                  NOT NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  "APPROVED_BY"                      RAW(16)               NULL,
  "PUBLISHED_AT"                     TIMESTAMP(6)          NULL,
  CONSTRAINT "UK_RECIPE_VERSIONS_C7DC41BD" UNIQUE ("ID"),
  CONSTRAINT "UK_RECIPE_VERSIONS_DD3C04EE" UNIQUE ("RECIPE_ID", "VERSION_NO")
);

CREATE TABLE "RECIPE_INGREDIENTS" (
  "ID"                               RAW(16)               NOT NULL,
  "RECIPE_VERSION_ID"                RAW(16)               NOT NULL,
  "LINE_NO"                          INTEGER               NOT NULL,
  "INGREDIENT_ID"                    RAW(16)               NOT NULL,
  "UNIT_ID"                          RAW(16)               NOT NULL,
  "QUANTITY"                         NUMBER(18,6)          NOT NULL,
  "PREPARATION_NOTE"                 CLOB                  NULL,
  CONSTRAINT "UK_RECIPE_INGREDIENT_EEBEC8F8" UNIQUE ("ID"),
  CONSTRAINT "UK_RECIPE_INGREDIENT_FD2DC717" UNIQUE ("RECIPE_VERSION_ID", "LINE_NO")
);

CREATE TABLE "MEAL_TYPES" (
  "ID"                               RAW(16)               NOT NULL,
  "CODE"                             VARCHAR2(200 CHAR)    NOT NULL,
  "NAME_MM"                          VARCHAR2(1000 CHAR)   NOT NULL,
  "SORT_ORDER"                       INTEGER               NOT NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  CONSTRAINT "UK_MEAL_TYPES_191B7EB1" UNIQUE ("ID"),
  CONSTRAINT "UK_MEAL_TYPES_05C62F82" UNIQUE ("CODE"),
  CONSTRAINT "CK_MEAL_TYPES_A5E31BD4" CHECK ("IS_ACTIVE" IN (0, 1))
);

CREATE TABLE "RECIPE_MEAL_TYPES" (
  "ID"                               RAW(16)               NOT NULL,
  "RECIPE_VERSION_ID"                RAW(16)               NOT NULL,
  "MEAL_TYPE_ID"                     RAW(16)               NOT NULL,
  CONSTRAINT "UK_RECIPE_MEAL_TYPES_0F34142B" UNIQUE ("ID"),
  CONSTRAINT "UK_RECIPE_MEAL_TYPES_1E026AD3" UNIQUE ("RECIPE_VERSION_ID", "MEAL_TYPE_ID")
);

CREATE TABLE "RECIPE_PAIRINGS" (
  "ID"                               RAW(16)               NOT NULL,
  "RECIPE_VERSION_ID"                RAW(16)               NOT NULL,
  "COMPANION_VERSION_ID"             RAW(16)               NOT NULL,
  "COMPATIBILITY_SCORE"              INTEGER               NOT NULL,
  "REASON"                           CLOB                  NULL,
  CONSTRAINT "UK_RECIPE_PAIRINGS_741E0CF4" UNIQUE ("ID"),
  CONSTRAINT "UK_RECIPE_PAIRINGS_B17A232E" UNIQUE ("RECIPE_VERSION_ID", "COMPANION_VERSION_ID")
);

-- 07 Nutrition and planning rule setup

CREATE TABLE "NUTRIENTS" (
  "ID"                               RAW(16)               NOT NULL,
  "CODE"                             VARCHAR2(200 CHAR)    NOT NULL,
  "NAME"                             VARCHAR2(1000 CHAR)   NOT NULL,
  "UNIT_ID"                          RAW(16)               NOT NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  CONSTRAINT "UK_NUTRIENTS_20BFF297" UNIQUE ("ID"),
  CONSTRAINT "UK_NUTRIENTS_A54006CC" UNIQUE ("CODE"),
  CONSTRAINT "CK_NUTRIENTS_54FBAF67" CHECK ("IS_ACTIVE" IN (0, 1))
);

CREATE TABLE "INGREDIENT_NUTRIENTS" (
  "ID"                               RAW(16)               NOT NULL,
  "INGREDIENT_ID"                    RAW(16)               NOT NULL,
  "NUTRIENT_ID"                      RAW(16)               NOT NULL,
  "BASIS_QUANTITY"                   NUMBER(18,6)          NOT NULL,
  "BASIS_UNIT_ID"                    RAW(16)               NOT NULL,
  "NUTRIENT_AMOUNT"                  NUMBER(18,6)          NOT NULL,
  "SOURCE_REFERENCE"                 VARCHAR2(1000 CHAR)   NOT NULL,
  "VERIFIED_AT"                      TIMESTAMP(6)          NULL,
  CONSTRAINT "UK_INGREDIENT_NUTRIE_649DF86B" UNIQUE ("ID"),
  CONSTRAINT "UK_INGREDIENT_NUTRIE_269B4964" UNIQUE ("INGREDIENT_ID", "NUTRIENT_ID")
);

CREATE TABLE "DIETARY_PROFILES" (
  "ID"                               RAW(16)               NOT NULL,
  "CODE"                             VARCHAR2(200 CHAR)    NOT NULL,
  "VERSION_NO"                       INTEGER               NOT NULL,
  "NAME"                             VARCHAR2(1000 CHAR)   NOT NULL,
  "CONSTRAINTS_JSON"                 CLOB                  NOT NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  "APPROVED_BY"                      RAW(16)               NULL,
  "PUBLISHED_AT"                     TIMESTAMP(6)          NULL,
  CONSTRAINT "UK_DIETARY_PROFILES_221B777B" UNIQUE ("ID"),
  CONSTRAINT "UK_DIETARY_PROFILES_D9ED3F10" UNIQUE ("CODE", "VERSION_NO"),
  CONSTRAINT "CK_DIETARY_PROFILES_FF8CAF69" CHECK ("CONSTRAINTS_JSON" IS JSON STRICT)
);

CREATE TABLE "PLANNING_RULE_SETS" (
  "ID"                               RAW(16)               NOT NULL,
  "CODE"                             VARCHAR2(200 CHAR)    NOT NULL,
  "VERSION_NO"                       INTEGER               NOT NULL,
  "NAME"                             VARCHAR2(1000 CHAR)   NOT NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  "APPROVED_BY"                      RAW(16)               NULL,
  "PUBLISHED_AT"                     TIMESTAMP(6)          NULL,
  CONSTRAINT "UK_PLANNING_RULE_SET_18B57AEF" UNIQUE ("ID"),
  CONSTRAINT "UK_PLANNING_RULE_SET_BB3A53AC" UNIQUE ("CODE", "VERSION_NO")
);

CREATE TABLE "PLANNING_RULES" (
  "ID"                               RAW(16)               NOT NULL,
  "RULE_SET_ID"                      RAW(16)               NOT NULL,
  "CODE"                             VARCHAR2(200 CHAR)    NOT NULL,
  "RULE_TYPE"                        VARCHAR2(1000 CHAR)   NOT NULL,
  "CONSTRAINT_LEVEL"                 VARCHAR2(1000 CHAR)   NOT NULL,
  "PRIORITY_WEIGHT"                  NUMBER(18,6)          NOT NULL,
  "PARAMETERS_JSON"                  CLOB                  NOT NULL,
  "EXPLANATION"                      CLOB                  NOT NULL,
  CONSTRAINT "UK_PLANNING_RULES_1693CA03" UNIQUE ("ID"),
  CONSTRAINT "UK_PLANNING_RULES_45A6C1AF" UNIQUE ("RULE_SET_ID", "CODE"),
  CONSTRAINT "CK_PLANNING_RULES_BBB5CAF8" CHECK ("PARAMETERS_JSON" IS JSON STRICT)
);

-- 08 Meal plans shopping lists and carts

CREATE TABLE "MEAL_PLANS" (
  "ID"                               RAW(16)               NOT NULL,
  "HOUSEHOLD_ID"                     RAW(16)               NOT NULL,
  "REFERENCE_BRANCH_ID"              RAW(16)               NULL,
  "RULE_SET_ID"                      RAW(16)               NOT NULL,
  "WEEK_START"                       DATE                  NOT NULL,
  "REVISION_NO"                      INTEGER               NOT NULL,
  "BUDGET_LIMIT"                     NUMBER(18,2)          NULL,
  "CURRENCY"                         CHAR(3 CHAR)          NOT NULL,
  "DIETARY_SNAPSHOT"                 CLOB                  NOT NULL,
  "ESTIMATED_FOOD_COST"              NUMBER(18,2)          NULL,
  "ESTIMATED_PACK_COST"              NUMBER(18,2)          NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  "CREATED_AT"                       TIMESTAMP(6)          NOT NULL,
  CONSTRAINT "UK_MEAL_PLANS_AB471647" UNIQUE ("ID"),
  CONSTRAINT "UK_MEAL_PLANS_3DA17D14" UNIQUE ("HOUSEHOLD_ID", "WEEK_START", "REVISION_NO"),
  CONSTRAINT "UK_MEAL_PLANS_BEF07A61" UNIQUE ("HOUSEHOLD_ID", "ID"),
  CONSTRAINT "CK_MEAL_PLANS_682C5B8B" CHECK ("DIETARY_SNAPSHOT" IS JSON STRICT)
);

CREATE TABLE "MEAL_SLOTS" (
  "ID"                               RAW(16)               NOT NULL,
  "MEAL_PLAN_ID"                     RAW(16)               NOT NULL,
  "MEAL_DATE"                        DATE                  NOT NULL,
  "MEAL_TYPE_ID"                     RAW(16)               NOT NULL,
  "DINER_COUNT"                      INTEGER               NOT NULL,
  "SERVING_UNITS"                    NUMBER(18,6)          NOT NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  CONSTRAINT "UK_MEAL_SLOTS_A90A14EC" UNIQUE ("ID"),
  CONSTRAINT "UK_MEAL_SLOTS_09A4D3C5" UNIQUE ("MEAL_PLAN_ID", "MEAL_DATE", "MEAL_TYPE_ID")
);

CREATE TABLE "MEAL_SLOT_RECIPES" (
  "ID"                               RAW(16)               NOT NULL,
  "MEAL_SLOT_ID"                     RAW(16)               NOT NULL,
  "RECIPE_VERSION_ID"                RAW(16)               NOT NULL,
  "POSITION_NO"                      INTEGER               NOT NULL,
  "DISH_ROLE"                        VARCHAR2(1000 CHAR)   NOT NULL,
  "SERVING_MULTIPLIER"               NUMBER(18,6)          NOT NULL,
  "NUTRITION_SNAPSHOT"               CLOB                  NOT NULL,
  CONSTRAINT "UK_MEAL_SLOT_RECIPES_187AD3E1" UNIQUE ("ID"),
  CONSTRAINT "UK_MEAL_SLOT_RECIPES_353BB7E8" UNIQUE ("MEAL_SLOT_ID", "POSITION_NO"),
  CONSTRAINT "CK_MEAL_SLOT_RECIPES_D2A76F23" CHECK ("NUTRITION_SNAPSHOT" IS JSON STRICT)
);

CREATE TABLE "SHOPPING_LISTS" (
  "ID"                               RAW(16)               NOT NULL,
  "HOUSEHOLD_ID"                     RAW(16)               NOT NULL,
  "MEAL_PLAN_ID"                     RAW(16)               NOT NULL,
  "REVISION_NO"                      INTEGER               NOT NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  "GENERATED_AT"                     TIMESTAMP(6)          NOT NULL,
  CONSTRAINT "UK_SHOPPING_LISTS_EE4F9A50" UNIQUE ("ID"),
  CONSTRAINT "UK_SHOPPING_LISTS_08D0BC47" UNIQUE ("MEAL_PLAN_ID", "REVISION_NO"),
  CONSTRAINT "UK_SHOPPING_LISTS_EB4F0F72" UNIQUE ("HOUSEHOLD_ID", "ID")
);

CREATE TABLE "SHOPPING_ITEMS" (
  "ID"                               RAW(16)               NOT NULL,
  "SHOPPING_LIST_ID"                 RAW(16)               NOT NULL,
  "INGREDIENT_ID"                    RAW(16)               NOT NULL,
  "REQUIRED_BASE_QTY"                NUMBER(18,6)          NOT NULL,
  "PANTRY_BASE_QTY"                  NUMBER(18,6)          NOT NULL,
  "OUTSIDE_BASE_QTY"                 NUMBER(18,6)          NOT NULL,
  "PORTAL_BASE_QTY"                  NUMBER(18,6)          NOT NULL,
  CONSTRAINT "UK_SHOPPING_ITEMS_5E59E8EA" UNIQUE ("ID"),
  CONSTRAINT "UK_SHOPPING_ITEMS_E53DD888" UNIQUE ("SHOPPING_LIST_ID", "INGREDIENT_ID")
);

CREATE TABLE "MEAL_FEEDBACK" (
  "ID"                               RAW(16)               NOT NULL,
  "MEAL_SLOT_RECIPE_ID"              RAW(16)               NOT NULL,
  "USER_ID"                          RAW(16)               NOT NULL,
  "RATING"                           INTEGER               NOT NULL,
  "COMMENT"                          CLOB                  NULL,
  "CREATED_AT"                       TIMESTAMP(6)          NOT NULL,
  CONSTRAINT "UK_MEAL_FEEDBACK_0EF2D9CF" UNIQUE ("ID"),
  CONSTRAINT "UK_MEAL_FEEDBACK_26499C60" UNIQUE ("MEAL_SLOT_RECIPE_ID", "USER_ID")
);

CREATE TABLE "CARTS" (
  "ID"                               RAW(16)               NOT NULL,
  "HOUSEHOLD_ID"                     RAW(16)               NOT NULL,
  "BRANCH_ID"                        RAW(16)               NOT NULL,
  "ADDRESS_ID"                       RAW(16)               NULL,
  "SHOPPING_LIST_ID"                 RAW(16)               NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  "UPDATED_AT"                       TIMESTAMP(6)          NOT NULL,
  CONSTRAINT "UK_CARTS_D77C2F55" UNIQUE ("ID"),
  CONSTRAINT "UK_CARTS_EA2D0390" UNIQUE ("BRANCH_ID", "ID"),
  CONSTRAINT "UK_CARTS_4E8749E2" UNIQUE ("BRANCH_ID", "HOUSEHOLD_ID", "ID")
);

CREATE TABLE "CART_ITEMS" (
  "ID"                               RAW(16)               NOT NULL,
  "BRANCH_ID"                        RAW(16)               NOT NULL,
  "CART_ID"                          RAW(16)               NOT NULL,
  "BRANCH_PRODUCT_ID"                RAW(16)               NOT NULL,
  "SHOPPING_ITEM_ID"                 RAW(16)               NULL,
  "QUANTITY_PACKS"                   INTEGER               NOT NULL,
  "QUOTED_UNIT_PRICE"                NUMBER(18,2)          NOT NULL,
  "CURRENCY"                         CHAR(3 CHAR)          NOT NULL,
  CONSTRAINT "UK_CART_ITEMS_96CDF11F" UNIQUE ("ID"),
  CONSTRAINT "UK_CART_ITEMS_1569F899" UNIQUE ("CART_ID", "BRANCH_PRODUCT_ID")
);

-- 09 Inventory lots transfers and reservations

CREATE TABLE "STOCK_RECEIPTS" (
  "ID"                               RAW(16)               NOT NULL,
  "BRANCH_ID"                        RAW(16)               NOT NULL,
  "WAREHOUSE_ID"                     RAW(16)               NOT NULL,
  "SOURCE_REFERENCE"                 VARCHAR2(1000 CHAR)   NULL,
  "RECEIVED_BY"                      RAW(16)               NOT NULL,
  "RECEIVED_AT"                      TIMESTAMP(6)          NOT NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  CONSTRAINT "UK_STOCK_RECEIPTS_568269DF" UNIQUE ("ID"),
  CONSTRAINT "UK_STOCK_RECEIPTS_68B41470" UNIQUE ("WAREHOUSE_ID", "ID")
);

CREATE TABLE "STOCK_RECEIPT_ITEMS" (
  "ID"                               RAW(16)               NOT NULL,
  "WAREHOUSE_ID"                     RAW(16)               NOT NULL,
  "RECEIPT_ID"                       RAW(16)               NOT NULL,
  "LOT_ID"                           RAW(16)               NOT NULL,
  "QUANTITY_PACKS"                   INTEGER               NOT NULL,
  "UNIT_COST"                        NUMBER(18,2)          NOT NULL,
  CONSTRAINT "UK_STOCK_RECEIPT_ITE_9CC554AC" UNIQUE ("ID"),
  CONSTRAINT "UK_STOCK_RECEIPT_ITE_F6E985E3" UNIQUE ("RECEIPT_ID", "LOT_ID")
);

CREATE TABLE "INVENTORY_LOTS" (
  "ID"                               RAW(16)               NOT NULL,
  "BRANCH_ID"                        RAW(16)               NOT NULL,
  "WAREHOUSE_ID"                     RAW(16)               NOT NULL,
  "PRODUCT_ID"                       RAW(16)               NOT NULL,
  "LOT_CODE"                         VARCHAR2(200 CHAR)    NOT NULL,
  "RECEIVED_ON"                      DATE                  NOT NULL,
  "EXPIRES_ON"                       DATE                  NULL,
  "ON_HAND_PACKS"                    INTEGER               NOT NULL,
  "RESERVED_PACKS"                   INTEGER               NOT NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  CONSTRAINT "UK_INVENTORY_LOTS_1CDBA403" UNIQUE ("ID"),
  CONSTRAINT "UK_INVENTORY_LOTS_00F3CFE8" UNIQUE ("WAREHOUSE_ID", "PRODUCT_ID", "LOT_CODE"),
  CONSTRAINT "UK_INVENTORY_LOTS_DE53A56B" UNIQUE ("WAREHOUSE_ID", "ID"),
  CONSTRAINT "UK_INVENTORY_LOTS_A4916759" UNIQUE ("WAREHOUSE_ID", "ID", "PRODUCT_ID"),
  CONSTRAINT "UK_INVENTORY_LOTS_F1B41F5C" UNIQUE ("BRANCH_ID", "ID", "PRODUCT_ID")
);

CREATE TABLE "STOCK_TRANSFERS" (
  "ID"                               RAW(16)               NOT NULL,
  "TRANSFER_NO"                      VARCHAR2(200 CHAR)    NOT NULL,
  "FROM_WAREHOUSE_ID"                RAW(16)               NOT NULL,
  "TO_WAREHOUSE_ID"                  RAW(16)               NOT NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  "CREATED_BY"                       RAW(16)               NOT NULL,
  "DISPATCHED_AT"                    TIMESTAMP(6)          NULL,
  "RECEIVED_AT"                      TIMESTAMP(6)          NULL,
  CONSTRAINT "UK_STOCK_TRANSFERS_ECB60CDC" UNIQUE ("ID"),
  CONSTRAINT "UK_STOCK_TRANSFERS_4A25CC5F" UNIQUE ("TRANSFER_NO"),
  CONSTRAINT "UK_STOCK_TRANSFERS_75758661" UNIQUE ("ID", "FROM_WAREHOUSE_ID", "TO_WAREHOUSE_ID")
);

CREATE TABLE "STOCK_TRANSFER_ITEMS" (
  "ID"                               RAW(16)               NOT NULL,
  "TRANSFER_ID"                      RAW(16)               NOT NULL,
  "LINE_NO"                          INTEGER               NOT NULL,
  "FROM_WAREHOUSE_ID"                RAW(16)               NOT NULL,
  "TO_WAREHOUSE_ID"                  RAW(16)               NOT NULL,
  "PRODUCT_ID"                       RAW(16)               NOT NULL,
  "SOURCE_LOT_ID"                    RAW(16)               NOT NULL,
  "DESTINATION_LOT_ID"               RAW(16)               NULL,
  "DISPATCHED_PACKS"                 INTEGER               NOT NULL,
  "RECEIVED_PACKS"                   INTEGER               NOT NULL,
  "DAMAGED_PACKS"                    INTEGER               NOT NULL,
  CONSTRAINT "UK_STOCK_TRANSFER_IT_E89DF8D9" UNIQUE ("ID"),
  CONSTRAINT "UK_STOCK_TRANSFER_IT_DF55DBD7" UNIQUE ("TRANSFER_ID", "LINE_NO")
);

CREATE TABLE "STOCK_RESERVATIONS" (
  "ID"                               RAW(16)               NOT NULL,
  "BRANCH_ID"                        RAW(16)               NOT NULL,
  "PRODUCT_ID"                       RAW(16)               NOT NULL,
  "ORDER_ITEM_ID"                    RAW(16)               NOT NULL,
  "LOT_ID"                           RAW(16)               NOT NULL,
  "QUANTITY_PACKS"                   INTEGER               NOT NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  "EXPIRES_AT"                       TIMESTAMP(6)          NULL,
  "CREATED_AT"                       TIMESTAMP(6)          NOT NULL,
  CONSTRAINT "UK_STOCK_RESERVATION_EE8E3FC5" UNIQUE ("ID"),
  CONSTRAINT "UK_STOCK_RESERVATION_C08EEC24" UNIQUE ("ORDER_ITEM_ID", "LOT_ID")
);

CREATE TABLE "INVENTORY_MOVEMENTS" (
  "ID"                               RAW(16)               NOT NULL,
  "LOT_ID"                           RAW(16)               NOT NULL,
  "QUANTITY_DELTA"                   INTEGER               NOT NULL,
  "MOVEMENT_TYPE"                    VARCHAR2(1000 CHAR)   NOT NULL,
  "RECEIPT_ITEM_ID"                  RAW(16)               NULL,
  "TRANSFER_ITEM_ID"                 RAW(16)               NULL,
  "RESERVATION_ID"                   RAW(16)               NULL,
  "ADJUSTMENT_REASON"                CLOB                  NULL,
  "ACTOR_USER_ID"                    RAW(16)               NULL,
  "OPERATION_KEY"                    VARCHAR2(200 CHAR)    NOT NULL,
  "OCCURRED_AT"                      TIMESTAMP(6)          NOT NULL,
  CONSTRAINT "UK_INVENTORY_MOVEMEN_04985F47" UNIQUE ("ID"),
  CONSTRAINT "UK_INVENTORY_MOVEMEN_B65C6740" UNIQUE ("OPERATION_KEY")
);

-- 10 Orders snapshots and change requests

CREATE TABLE "ORDERS" (
  "ID"                               RAW(16)               NOT NULL,
  "ORDER_NO"                         VARCHAR2(200 CHAR)    NOT NULL,
  "CHECKOUT_KEY"                     RAW(16)               NOT NULL,
  "HOUSEHOLD_ID"                     RAW(16)               NOT NULL,
  "BRANCH_ID"                        RAW(16)               NOT NULL,
  "SERVICE_AREA_ID"                  RAW(16)               NOT NULL,
  "ADDRESS_ID"                       RAW(16)               NOT NULL,
  "SOURCE_CART_ID"                   RAW(16)               NULL,
  "DELIVERY_SLOT_ID"                 RAW(16)               NOT NULL,
  "PAYMENT_METHOD_ID"                RAW(16)               NOT NULL,
  "CREATED_BY"                       RAW(16)               NOT NULL,
  "RECIPIENT_NAME_SNAPSHOT"          VARCHAR2(1000 CHAR)   NOT NULL,
  "RECIPIENT_PHONE_SNAPSHOT"         VARCHAR2(1000 CHAR)   NOT NULL,
  "ADDRESS_SNAPSHOT"                 CLOB                  NOT NULL,
  "DELIVERY_SLOT_SNAPSHOT"           CLOB                  NOT NULL,
  "CURRENCY"                         CHAR(3 CHAR)          NOT NULL,
  "ITEM_SUBTOTAL"                    NUMBER(18,2)          NOT NULL,
  "DELIVERY_FEE"                     NUMBER(18,2)          NOT NULL,
  "GRAND_TOTAL"                      NUMBER(18,2)          NOT NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  "PLACED_AT"                        TIMESTAMP(6)          NOT NULL,
  CONSTRAINT "UK_ORDERS_AC7850AE" UNIQUE ("ID"),
  CONSTRAINT "UK_ORDERS_C637182A" UNIQUE ("ORDER_NO"),
  CONSTRAINT "UK_ORDERS_5F68BD5F" UNIQUE ("CHECKOUT_KEY"),
  CONSTRAINT "UK_ORDERS_01C49F83" UNIQUE ("SOURCE_CART_ID"),
  CONSTRAINT "UK_ORDERS_CC3401D5" UNIQUE ("BRANCH_ID", "ID"),
  CONSTRAINT "CK_ORDERS_4EC8FB16" CHECK ("ADDRESS_SNAPSHOT" IS JSON STRICT),
  CONSTRAINT "CK_ORDERS_F35D6D12" CHECK ("DELIVERY_SLOT_SNAPSHOT" IS JSON STRICT)
);

CREATE TABLE "ORDER_ITEMS" (
  "ID"                               RAW(16)               NOT NULL,
  "ORDER_ID"                         RAW(16)               NOT NULL,
  "LINE_NO"                          INTEGER               NOT NULL,
  "BRANCH_ID"                        RAW(16)               NOT NULL,
  "BRANCH_PRODUCT_ID"                RAW(16)               NOT NULL,
  "PRODUCT_ID"                       RAW(16)               NOT NULL,
  "SHOPPING_ITEM_ID"                 RAW(16)               NULL,
  "SKU_SNAPSHOT"                     VARCHAR2(1000 CHAR)   NOT NULL,
  "NAME_SNAPSHOT"                    VARCHAR2(1000 CHAR)   NOT NULL,
  "PACK_QUANTITY_SNAPSHOT"           NUMBER(18,6)          NOT NULL,
  "PACK_UNIT_CODE_SNAPSHOT"          VARCHAR2(1000 CHAR)   NOT NULL,
  "BASE_QTY_PER_PACK_SNAPSHOT"       NUMBER(18,6)          NOT NULL,
  "QUANTITY_PACKS"                   INTEGER               NOT NULL,
  "UNIT_PRICE"                       NUMBER(18,2)          NOT NULL,
  "LINE_TOTAL"                       NUMBER(18,2)          NOT NULL,
  CONSTRAINT "UK_ORDER_ITEMS_9C51DE26" UNIQUE ("ID"),
  CONSTRAINT "UK_ORDER_ITEMS_AF0048EA" UNIQUE ("ORDER_ID", "LINE_NO"),
  CONSTRAINT "UK_ORDER_ITEMS_B7C384A4" UNIQUE ("BRANCH_ID", "ID", "PRODUCT_ID")
);

CREATE TABLE "ORDER_CHANGE_REQUESTS" (
  "ID"                               RAW(16)               NOT NULL,
  "ORDER_ID"                         RAW(16)               NOT NULL,
  "REQUEST_TYPE"                     VARCHAR2(1000 CHAR)   NOT NULL,
  "REQUESTED_BY"                     RAW(16)               NOT NULL,
  "REQUESTED_CHANGES"                CLOB                  NOT NULL,
  "REASON"                           CLOB                  NOT NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  "REVIEWED_BY"                      RAW(16)               NULL,
  "REQUESTED_AT"                     TIMESTAMP(6)          NOT NULL,
  "REVIEWED_AT"                      TIMESTAMP(6)          NULL,
  CONSTRAINT "UK_ORDER_CHANGE_REQU_0C63AB7B" UNIQUE ("ID"),
  CONSTRAINT "CK_ORDER_CHANGE_REQU_D9B90C9E" CHECK ("REQUESTED_CHANGES" IS JSON STRICT)
);

CREATE TABLE "ORDER_STATUS_HISTORY" (
  "ID"                               RAW(16)               NOT NULL,
  "ORDER_ID"                         RAW(16)               NOT NULL,
  "FROM_STATUS"                      VARCHAR2(1000 CHAR)   NULL,
  "TO_STATUS"                        VARCHAR2(1000 CHAR)   NOT NULL,
  "CHANGED_BY"                       RAW(16)               NULL,
  "REASON"                           CLOB                  NULL,
  "CHANGED_AT"                       TIMESTAMP(6)          NOT NULL,
  CONSTRAINT "UK_ORDER_STATUS_HIST_C85ECBEC" UNIQUE ("ID")
);

-- 11 Delivery slots runs and attempts

CREATE TABLE "DELIVERY_SLOTS" (
  "ID"                               RAW(16)               NOT NULL,
  "BRANCH_ID"                        RAW(16)               NOT NULL,
  "STARTS_AT"                        TIMESTAMP(6)          NOT NULL,
  "ENDS_AT"                          TIMESTAMP(6)          NOT NULL,
  "CUTOFF_AT"                        TIMESTAMP(6)          NOT NULL,
  "CAPACITY_ORDERS"                  INTEGER               NOT NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  CONSTRAINT "UK_DELIVERY_SLOTS_265892B2" UNIQUE ("ID"),
  CONSTRAINT "UK_DELIVERY_SLOTS_D623D850" UNIQUE ("BRANCH_ID", "STARTS_AT", "ENDS_AT"),
  CONSTRAINT "UK_DELIVERY_SLOTS_34F35A37" UNIQUE ("BRANCH_ID", "ID")
);

CREATE TABLE "DELIVERY_RUNS" (
  "ID"                               RAW(16)               NOT NULL,
  "BRANCH_ID"                        RAW(16)               NOT NULL,
  "DRIVER_USER_ID"                   RAW(16)               NOT NULL,
  "RUN_DATE"                         DATE                  NOT NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  "STARTED_AT"                       TIMESTAMP(6)          NULL,
  "COMPLETED_AT"                     TIMESTAMP(6)          NULL,
  CONSTRAINT "UK_DELIVERY_RUNS_8BE6C75F" UNIQUE ("ID"),
  CONSTRAINT "UK_DELIVERY_RUNS_D4C3432D" UNIQUE ("BRANCH_ID", "ID")
);

CREATE TABLE "DELIVERY_TASKS" (
  "ID"                               RAW(16)               NOT NULL,
  "ORDER_ID"                         RAW(16)               NOT NULL,
  "BRANCH_ID"                        RAW(16)               NOT NULL,
  "RUN_ID"                           RAW(16)               NULL,
  "STOP_SEQUENCE"                    INTEGER               NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  "ASSIGNED_AT"                      TIMESTAMP(6)          NULL,
  "DELIVERED_AT"                     TIMESTAMP(6)          NULL,
  CONSTRAINT "UK_DELIVERY_TASKS_62F2A1A6" UNIQUE ("ID"),
  CONSTRAINT "UK_DELIVERY_TASKS_58A1056C" UNIQUE ("ORDER_ID"),
  CONSTRAINT "UK_DELIVERY_TASKS_82082C31" UNIQUE ("RUN_ID", "STOP_SEQUENCE")
);

CREATE TABLE "DELIVERY_ATTEMPTS" (
  "ID"                               RAW(16)               NOT NULL,
  "DELIVERY_TASK_ID"                 RAW(16)               NOT NULL,
  "ATTEMPT_NO"                       INTEGER               NOT NULL,
  "ATTEMPTED_BY"                     RAW(16)               NOT NULL,
  "ATTEMPTED_AT"                     TIMESTAMP(6)          NOT NULL,
  "RESULT"                           VARCHAR2(1000 CHAR)   NOT NULL,
  "FAILURE_REASON"                   CLOB                  NULL,
  "PROOF_REFERENCE"                  VARCHAR2(1000 CHAR)   NULL,
  CONSTRAINT "UK_DELIVERY_ATTEMPTS_9F6D4912" UNIQUE ("ID"),
  CONSTRAINT "UK_DELIVERY_ATTEMPTS_B62F58B4" UNIQUE ("DELIVERY_TASK_ID", "ATTEMPT_NO")
);

-- 12 MMQR COD reconciliation and refunds

CREATE TABLE "PAYMENT_METHODS" (
  "ID"                               RAW(16)               NOT NULL,
  "CODE"                             VARCHAR2(200 CHAR)    NOT NULL,
  "NAME"                             VARCHAR2(1000 CHAR)   NOT NULL,
  "IS_ENABLED"                       NUMBER(1,0)           NOT NULL,
  CONSTRAINT "UK_PAYMENT_METHODS_2EA9585C" UNIQUE ("ID"),
  CONSTRAINT "UK_PAYMENT_METHODS_C13223DD" UNIQUE ("CODE"),
  CONSTRAINT "CK_PAYMENT_METHODS_39BF35F5" CHECK ("IS_ENABLED" IN (0, 1))
);

CREATE TABLE "MERCHANT_ACCOUNTS" (
  "ID"                               RAW(16)               NOT NULL,
  "PROVIDER_CODE"                    VARCHAR2(200 CHAR)    NOT NULL,
  "MERCHANT_REFERENCE"               VARCHAR2(200 CHAR)    NOT NULL,
  "OWNER_BRANCH_ID"                  RAW(16)               NULL,
  "DISPLAY_NAME"                     VARCHAR2(1000 CHAR)   NOT NULL,
  "CREDENTIAL_REFERENCE"             VARCHAR2(1000 CHAR)   NOT NULL,
  "IS_ACTIVE"                        NUMBER(1,0)           NOT NULL,
  CONSTRAINT "UK_MERCHANT_ACCOUNTS_E166E368" UNIQUE ("ID"),
  CONSTRAINT "UK_MERCHANT_ACCOUNTS_88471A19" UNIQUE ("PROVIDER_CODE", "MERCHANT_REFERENCE"),
  CONSTRAINT "CK_MERCHANT_ACCOUNTS_2F2CC39E" CHECK ("IS_ACTIVE" IN (0, 1))
);

CREATE TABLE "PAYMENTS" (
  "ID"                               RAW(16)               NOT NULL,
  "BRANCH_ID"                        RAW(16)               NOT NULL,
  "ORDER_ID"                         RAW(16)               NOT NULL,
  "PAYMENT_METHOD_ID"                RAW(16)               NOT NULL,
  "MERCHANT_ACCOUNT_ID"              RAW(16)               NULL,
  "ATTEMPT_NO"                       INTEGER               NOT NULL,
  "REQUEST_KEY"                      RAW(16)               NOT NULL,
  "AMOUNT"                           NUMBER(18,2)          NOT NULL,
  "CURRENCY"                         CHAR(3 CHAR)          NOT NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  "PROVIDER_TRANSACTION_ID"          VARCHAR2(200 CHAR)    NULL,
  "QR_PAYLOAD_REFERENCE"             VARCHAR2(1000 CHAR)   NULL,
  "EXPIRES_AT"                       TIMESTAMP(6)          NULL,
  "PAID_AT"                          TIMESTAMP(6)          NULL,
  "CREATED_AT"                       TIMESTAMP(6)          NOT NULL,
  CONSTRAINT "UK_PAYMENTS_9AC62280" UNIQUE ("ID"),
  CONSTRAINT "UK_PAYMENTS_C61CED38" UNIQUE ("REQUEST_KEY"),
  CONSTRAINT "UK_PAYMENTS_85F37CB7" UNIQUE ("ORDER_ID", "ATTEMPT_NO"),
  CONSTRAINT "UK_PAYMENTS_369D3EEC" UNIQUE ("ORDER_ID", "ID"),
  CONSTRAINT "UK_PAYMENTS_6B87652F" UNIQUE ("BRANCH_ID", "ID"),
  CONSTRAINT "UK_PAYMENTS_AE6280B1" UNIQUE ("MERCHANT_ACCOUNT_ID", "PROVIDER_TRANSACTION_ID")
);

CREATE TABLE "COD_COLLECTIONS" (
  "ID"                               RAW(16)               NOT NULL,
  "BRANCH_ID"                        RAW(16)               NOT NULL,
  "PAYMENT_ID"                       RAW(16)               NOT NULL,
  "DELIVERY_ATTEMPT_ID"              RAW(16)               NOT NULL,
  "COLLECTED_BY"                     RAW(16)               NOT NULL,
  "AMOUNT"                           NUMBER(18,2)          NOT NULL,
  "COLLECTED_AT"                     TIMESTAMP(6)          NOT NULL,
  "REMITTANCE_ID"                    RAW(16)               NULL,
  CONSTRAINT "UK_COD_COLLECTIONS_0295954D" UNIQUE ("ID"),
  CONSTRAINT "UK_COD_COLLECTIONS_9EEE5028" UNIQUE ("PAYMENT_ID"),
  CONSTRAINT "UK_COD_COLLECTIONS_BE1C1013" UNIQUE ("DELIVERY_ATTEMPT_ID")
);

CREATE TABLE "PAYMENT_EVENTS" (
  "ID"                               RAW(16)               NOT NULL,
  "MERCHANT_ACCOUNT_ID"              RAW(16)               NOT NULL,
  "PAYMENT_ID"                       RAW(16)               NULL,
  "PROVIDER_EVENT_ID"                VARCHAR2(200 CHAR)    NOT NULL,
  "PAYLOAD_HASH"                     VARCHAR2(1000 CHAR)   NOT NULL,
  "SANITIZED_PAYLOAD"                CLOB                  NOT NULL,
  "VERIFICATION_STATUS"              VARCHAR2(1000 CHAR)   NOT NULL,
  "PROCESSING_STATUS"                VARCHAR2(1000 CHAR)   NOT NULL,
  "RECEIVED_AT"                      TIMESTAMP(6)          NOT NULL,
  "PROCESSED_AT"                     TIMESTAMP(6)          NULL,
  CONSTRAINT "UK_PAYMENT_EVENTS_59F8A50C" UNIQUE ("ID"),
  CONSTRAINT "UK_PAYMENT_EVENTS_26206B9F" UNIQUE ("MERCHANT_ACCOUNT_ID", "PROVIDER_EVENT_ID"),
  CONSTRAINT "CK_PAYMENT_EVENTS_FEB58CAD" CHECK ("SANITIZED_PAYLOAD" IS JSON STRICT)
);

CREATE TABLE "REFUNDS" (
  "ID"                               RAW(16)               NOT NULL,
  "ORDER_ID"                         RAW(16)               NOT NULL,
  "PAYMENT_ID"                       RAW(16)               NOT NULL,
  "REQUEST_KEY"                      RAW(16)               NOT NULL,
  "AMOUNT"                           NUMBER(18,2)          NOT NULL,
  "REFUND_CHANNEL"                   VARCHAR2(1000 CHAR)   NOT NULL,
  "REASON"                           CLOB                  NOT NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  "REQUESTED_BY"                     RAW(16)               NOT NULL,
  "APPROVED_BY"                      RAW(16)               NULL,
  "PROVIDER_REFUND_REFERENCE"        VARCHAR2(1000 CHAR)   NULL,
  "REQUESTED_AT"                     TIMESTAMP(6)          NOT NULL,
  "REFUNDED_AT"                      TIMESTAMP(6)          NULL,
  CONSTRAINT "UK_REFUNDS_933EB09A" UNIQUE ("ID"),
  CONSTRAINT "UK_REFUNDS_770779E9" UNIQUE ("REQUEST_KEY")
);

CREATE TABLE "CASH_REMITTANCES" (
  "ID"                               RAW(16)               NOT NULL,
  "REFERENCE_NO"                     VARCHAR2(200 CHAR)    NOT NULL,
  "BRANCH_ID"                        RAW(16)               NOT NULL,
  "SUBMITTED_BY"                     RAW(16)               NOT NULL,
  "RECEIVED_BY"                      RAW(16)               NULL,
  "DECLARED_AMOUNT"                  NUMBER(18,2)          NOT NULL,
  "ACCEPTED_AMOUNT"                  NUMBER(18,2)          NULL,
  "DIFFERENCE_REASON"                CLOB                  NULL,
  "STATUS"                           VARCHAR2(1000 CHAR)   NOT NULL,
  "SUBMITTED_AT"                     TIMESTAMP(6)          NOT NULL,
  "RECEIVED_AT"                      TIMESTAMP(6)          NULL,
  CONSTRAINT "UK_CASH_REMITTANCES_2E10C385" UNIQUE ("ID"),
  CONSTRAINT "UK_CASH_REMITTANCES_CAEA45BC" UNIQUE ("REFERENCE_NO"),
  CONSTRAINT "UK_CASH_REMITTANCES_0B4C43DF" UNIQUE ("BRANCH_ID", "ID")
);

PROMPT Creating foreign keys after all referenced unique constraints exist...

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

PROMPT Completed: 69 tables, 508 columns, 156 unique constraints, 128 foreign keys.
