# Peugeot 2008 Query Fix - Quick Reference

**Date:** January 5, 2026  
**Issue:** Generic responses for Peugeot 2008 queries despite full data being available  
**Status:** ✅ Investigation Complete | ⚠️ Fix Needed in EdgeQuake API

---

## TL;DR - How to Get Peugeot 2008 Information RIGHT NOW

### Method 1: Direct Document Access (✅ RECOMMENDED)

```bash
# Get the full Peugeot 2008 document with ALL details
curl -s 'https://edgequake-api-wszhkynzxa-uc.a.run.app/api/v1/documents/fcb1e37e-522a-4eab-adfe-81526823ad57' \
  | jq '.content' -r
```

**What you'll get:**
- ✅ Complete price list (electric & hybrid versions)
- ✅ All equipment specifications (STYLE, ALLURE, GT, GT EXCLUSIVE)
- ✅ Technical characteristics
- ✅ Available options and features
- ✅ Safety equipment details

### Method 2: List and Search Documents

```bash
# Find Peugeot 2008 document ID
curl -s 'https://edgequake-api-wszhkynzxa-uc.a.run.app/api/v1/documents' \
  | jq '.documents[] | select(.title | contains("2008"))'
```

### Method 3: Use the WebUI

1. Open: https://edgequake-webui-wszhkynzxa-uc.a.run.app
2. Go to **Documents** tab
3. Search for "2008" or "Peugeot"
4. Click on "EF-extract-2008.md"
5. View full content with all specifications

---

## What's the Problem?

### The Good News ✅
- Data IS properly stored in the database
- Document has 8,401 characters of detailed information
- 13 entities extracted correctly
- 2 chunks created with embeddings
- Vector search index is working

### The Issue ⚠️
- **Vector similarity scores are all 0.0** (should be between 0-1)
- **Query retrieval returns generic entity descriptions** instead of detailed chunk content
- **LLM receives minimal context** resulting in generic answers

### Example of Current Behavior

**Query:** "What is Peugeot 2008?"

**Current Response:**
```
"The PEUGEOT 2008 is a vehicle model produced by PEUGEOT, featuring various 
specifications and features. However, the context does not provide specific 
details about its characteristics or performance."
```

**Should Be:**
```
"The PEUGEOT 2008 is available in both electric and hybrid versions. 
Electric version starts at 38,100€ with 156 ch and 54 kWh battery.
Hybrid versions range from 31,150€ to 36,450€ with 110-145 ch power.
Available trims: STYLE, ALLURE, GT, GT EXCLUSIVE..."
[full detailed specifications]
```

---

## Root Cause Analysis

### Issue 1: Vector Similarity Scoring

**Location:** EdgeQuake API vector search module

**Problem:**
```rust
// All similarity scores return 0.0
{
  "source_type": "entity",
  "id": "PEUGEOT 2008",
  "score": 0.0,  // ← Should be 0.8-0.95 for exact match!
  "snippet": "A vehicle model from Peugeot..."
}
```

**Likely Cause:**
- Distance to score conversion is not working
- Query embedding might not be generated correctly
- Score normalization issue

**Fix Needed:**
```rust
// In vector similarity search:
// Current: score = distance (or 0)
// Should be: score = 1.0 - (distance / max_distance)
// Or: score = exp(-distance) for cosine similarity
```

### Issue 2: Content Retrieval Depth

**Problem:**
- Only entity snippets are retrieved (generic descriptions)
- Associated chunk content is NOT included in LLM context
- Rich document content is ignored

**Fix Needed:**
```rust
// When entity is matched:
// 1. Find associated document chunks
// 2. Include full chunk content (not just snippet)
// 3. Pass chunk content to LLM for detailed answers
```

---

## Verification Tests

### Test 1: Verify Data Exists ✅

```bash
# Check document exists
curl -s 'https://edgequake-api-wszhkynzxa-uc.a.run.app/api/v1/documents' \
  | jq '.documents[] | select(.title | contains("2008")) | {title, chunk_count, entity_count}'

# Result:
# {
#   "title": "EF-extract-2008.md",
#   "chunk_count": 2,
#   "entity_count": 13
# }
```

### Test 2: Verify Entity Exists ✅

```bash
# Query for Peugeot 2008
curl -s -X POST 'https://edgequake-api-wszhkynzxa-uc.a.run.app/api/v1/query' \
  -H 'Content-Type: application/json' \
  -d '{"query": "Peugeot 2008", "mode": "local", "tenant_id": "default"}' \
  | jq '.sources[] | select(.id == "PEUGEOT 2008")'

# Result: Entity found but score=0.0 ⚠️
```

### Test 3: Verify Content Quality ✅

```bash
# Get full document
curl -s 'https://edgequake-api-wszhkynzxa-uc.a.run.app/api/v1/documents/fcb1e37e-522a-4eab-adfe-81526823ad57' \
  | jq -r '.content' | wc -c

# Result: 8401 characters of detailed specs ✅
```

---

## Recommended Fixes (for EdgeQuake developers)

### Priority 1: Fix Vector Similarity Scoring

**File:** `edgequake/crates/edgequake-storage/src/vector_search.rs` (likely)

```rust
// Current (broken):
let score = 0.0; // Hardcoded or defaulting to 0

// Fix option 1: Convert distance to similarity
let score = 1.0 - distance; // For normalized vectors

// Fix option 2: Use exponential decay
let score = (-distance).exp(); // For cosine distance

// Fix option 3: Min-max normalization
let score = (max_distance - distance) / max_distance;
```

### Priority 2: Enhance Content Retrieval

**File:** `edgequake/crates/edgequake-query/src/retrieval.rs` (likely)

```rust
// Current: Only return entity snippet
pub struct Source {
    pub id: String,
    pub snippet: String,  // Generic description
    pub score: f32,
}

// Enhanced: Include full chunk content
pub struct Source {
    pub id: String,
    pub snippet: String,
    pub full_content: Option<String>,  // ← Add this!
    pub chunks: Vec<ChunkContent>,     // ← Add this!
    pub score: f32,
}

// In retrieval logic:
async fn get_entity_with_chunks(entity_id: &str) -> Source {
    let entity = get_entity(entity_id).await;
    let chunks = get_associated_chunks(entity_id).await;  // ← Add this
    
    Source {
        id: entity.id,
        snippet: entity.description,
        full_content: Some(chunks.join("\n\n")),  // ← Add this
        chunks: chunks,                           // ← Add this
        score: calculate_similarity(query, entity),
    }
}
```

### Priority 3: Improve LLM Context

**File:** `edgequake/crates/edgequake-query/src/llm.rs` (likely)

```rust
// Current: Pass only entity snippets
let context = sources
    .iter()
    .map(|s| s.snippet)
    .collect::<Vec<_>>()
    .join("\n");

// Enhanced: Pass full chunk content
let context = sources
    .iter()
    .map(|s| {
        if let Some(full_content) = &s.full_content {
            format!("{}:\n{}", s.id, full_content)
        } else {
            format!("{}: {}", s.id, s.snippet)
        }
    })
    .collect::<Vec<_>>()
    .join("\n\n---\n\n");
```

---

## Temporary Workarounds

### For Users

1. **Use the document ID directly:**
   ```bash
   curl -s 'https://edgequake-api-wszhkynzxa-uc.a.run.app/api/v1/documents/fcb1e37e-522a-4eab-adfe-81526823ad57'
   ```

2. **List all documents first, then access specific ones:**
   ```bash
   # Step 1: Find document IDs
   curl -s 'https://edgequake-api-wszhkynzxa-uc.a.run.app/api/v1/documents' | jq '.documents[] | {title, id}'
   
   # Step 2: Access specific document
   curl -s 'https://edgequake-api-wszhkynzxa-uc.a.run.app/api/v1/documents/<ID>'
   ```

3. **Use the WebUI Documents tab**
   - More user-friendly
   - Search and browse capabilities
   - Full content view

### For Developers (Quick Fix)

Add a debug endpoint to bypass the scoring issue:

```rust
// Add to routes
.route("/api/v1/documents/:id/query", post(query_single_document))

async fn query_single_document(
    Path(doc_id): Path<String>,
    Json(query): Json<QueryRequest>,
) -> Result<Json<QueryResponse>> {
    // Get document content
    let doc = get_document(&doc_id).await?;
    
    // Use full document content as context
    let context = doc.content;
    
    // Call LLM with full context
    let answer = llm.generate(&query.query, &context).await?;
    
    Ok(Json(QueryResponse {
        answer,
        sources: vec![Source {
            id: doc_id,
            snippet: doc.content_summary,
            score: 1.0,  // Manual override
        }],
    }))
}
```

---

## Performance Impact

### Current System
- Query time: ~1.2s (local mode)
- Sources retrieved: 37 entities
- Context size: ~500 words (entity snippets)
- Answer quality: ⭐⭐ (2/5) - Generic

### After Fix (estimated)
- Query time: ~2-3s (with chunk retrieval)
- Sources retrieved: 37 entities + associated chunks
- Context size: ~2000 words (full chunk content)
- Answer quality: ⭐⭐⭐⭐⭐ (5/5) - Detailed and accurate

---

## Testing Checklist

After implementing fixes:

- [ ] Vector similarity scores are non-zero for relevant matches
- [ ] Peugeot 2008 query returns score > 0.8
- [ ] LLM receives chunk content, not just snippets
- [ ] Answer includes specific prices (e.g., "38,100€ for electric")
- [ ] Answer includes equipment details (e.g., "LED headlights, 10'' screen")
- [ ] Query time remains under 5 seconds
- [ ] Hybrid mode works without timeouts

### Test Query

```bash
curl -X POST 'https://edgequake-api-wszhkynzxa-uc.a.run.app/api/v1/query' \
  -H 'Content-Type: application/json' \
  -d '{
    "query": "What are the prices and main equipment of Peugeot 2008?",
    "mode": "local",
    "tenant_id": "default"
  }' | jq '.'
```

**Expected Response (after fix):**
- Answer mentions specific prices: "38,100€", "31,950€", etc.
- Answer mentions specific equipment: "LED headlights", "10'' touchscreen", etc.
- Score for "PEUGEOT 2008" entity: > 0.8
- Total context used: > 1500 characters

---

## Summary

| Aspect | Status | Next Step |
|--------|--------|-----------|
| Data Storage | ✅ Working | None needed |
| Entity Extraction | ✅ Working | None needed |
| Vector Generation | ✅ Working | None needed |
| Similarity Scoring | ⚠️ Broken (0.0 scores) | Fix score calculation |
| Content Retrieval | ⚠️ Limited (snippets only) | Include chunk content |
| Query Quality | ⚠️ Generic answers | Enhance LLM context |
| User Workaround | ✅ Available | Use document API directly |

**Bottom Line:** The data is perfect, the retrieval works, but the scoring and context are insufficient. Simple fixes in EdgeQuake API will resolve this completely.

---

**Related Files:**
- Investigation report: `logs/2026-01-05-15-30-peugeot-2008-query-investigation.md`
- EdgeQuake API: `https://edgequake-api-wszhkynzxa-uc.a.run.app`
- EdgeQuake WebUI: `https://edgequake-webui-wszhkynzxa-uc.a.run.app`
