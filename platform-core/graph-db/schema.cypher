// Node Labels: Project, Function, Library, Issue

// 1. Vector Indexes for Semantic Search
CREATE VECTOR INDEX code_embedding_index IF NOT EXISTS
FOR (n:Function) ON (n.embedding)
OPTIONS {indexConfig: {
 `vector.dimensions`: 1536,
 `vector.similarity_function`: 'cosine'
}};

CREATE VECTOR INDEX issue_embedding_index IF NOT EXISTS
FOR (n:Issue) ON (n.embedding)
OPTIONS {indexConfig: {
 `vector.dimensions`: 1536,
 `vector.similarity_function`: 'cosine'
}};

// 2. Fulltext Indexes for Keyword Search
CREATE FULLTEXT INDEX function_name_index IF NOT EXISTS
FOR (n:Function) ON EACH [n.name];

CREATE FULLTEXT INDEX library_name_index IF NOT EXISTS
FOR (n:Library) ON EACH [n.name];
