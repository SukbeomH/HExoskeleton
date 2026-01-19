// Ensure URNs are unique across all key entities

CREATE CONSTRAINT function_urn_unique IF NOT EXISTS
FOR (n:Function) REQUIRE n.urn IS UNIQUE;

CREATE CONSTRAINT library_urn_unique IF NOT EXISTS
FOR (n:Library) REQUIRE n.urn IS UNIQUE;

CREATE CONSTRAINT project_urn_unique IF NOT EXISTS
FOR (n:Project) REQUIRE n.urn IS UNIQUE;

CREATE CONSTRAINT issue_urn_unique IF NOT EXISTS
FOR (n:Issue) REQUIRE n.urn IS UNIQUE;
