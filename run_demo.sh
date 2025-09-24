#!/usr/bin/env bash
set -euo pipefail

RESULTS_DIR="results"
DATA_DIR="data"
mkdir -p "${RESULTS_DIR}"

echo "== robot version =="
robot --version


# --- Convert seed TTLs to OWL for convenience --------------------------------
robot convert --input "${DATA_DIR}/base.ttl"   --output "${DATA_DIR}/base.owl"
robot convert --input "${DATA_DIR}/extra.ttl"  --output "${DATA_DIR}/extra.owl"
robot convert --input "${DATA_DIR}/nucleus.ttl" --output "${DATA_DIR}/nucleus.owl"
robot convert --input "${DATA_DIR}/imports-nucleus.ttl" --output "${DATA_DIR}/imports-nucleus.owl"

# --- COMMAND SHOWCASE -----------------------------------------------------

echo "== annotate =="
robot annotate \
  --input "${DATA_DIR}/base.owl" \
  --ontology-iri "http://example.com/ontology" \
  --version-iri "http://example.com/ontology/2025-09-24" \
  --annotation rdfs:label "Example Ontology" \
  --annotation rdfs:comment "Demo created by robot_demo.sh" \
  --output "${RESULTS_DIR}/annotated.owl"

echo "== reason (ELK) =="
robot reason \
  --reasoner ELK \
  --input "${RESULTS_DIR}/annotated.owl" \
  --output "${RESULTS_DIR}/reasoned.owl"

echo "== relax =="
robot relax \
  --input "${RESULTS_DIR}/reasoned.owl" \
  --output "${RESULTS_DIR}/relaxed.owl"

echo "== reduce =="
robot reduce \
  --reasoner ELK \
  --input "${RESULTS_DIR}/relaxed.owl" \
  --output "${RESULTS_DIR}/reduced.owl"

echo "== export (table) =="
robot export \
  --input "${RESULTS_DIR}/reduced.owl" \
  --header "ID|LABEL" \
  --export "${RESULTS_DIR}/terms.csv"


echo "== materialize (add inferred axioms explicitly) =="
robot materialize \
  --reasoner ELK \
  --input "${RESULTS_DIR}/reduced.owl" \
  --output "${RESULTS_DIR}/materialized.owl"

echo "== measure (metrics) =="
robot measure \
  --input "${RESULTS_DIR}/materialized.owl" \
   --metrics all \
   --output "${RESULTS_DIR}/metrics.tsv"

echo "== merge (base + extra) =="
robot merge \
  --input "${RESULTS_DIR}/materialized.owl" \
  --input "${DATA_DIR}/extra.owl" \
  --output "${RESULTS_DIR}/merged.owl"

echo "== diff (materialized vs merged) =="
robot diff \
  --left  "${RESULTS_DIR}/materialized.owl" \
  --right "${RESULTS_DIR}/merged.owl" \
  --output "${RESULTS_DIR}/diff.txt"

echo "== convert (to TTL and OBO) =="
robot convert --input "${RESULTS_DIR}/merged.owl" --format ttl --output "${RESULTS_DIR}/merged.ttl"
robot convert --input "${RESULTS_DIR}/merged.owl" --format obo --output "${RESULTS_DIR}/merged.obo"

echo "== query (missing labels to TSV) =="
robot query \
  --input "${RESULTS_DIR}/merged.owl" \
  --query "${DATA_DIR}/missing_labels.sparql" \
  "${RESULTS_DIR}/missing_labels.tsv"

echo "== verify (fail if any unlabeled entities exist) =="
# This ASK returns true if missing labels exist; verify converts true -> failure
set +e
robot verify \
  --input "${RESULTS_DIR}/merged.owl" \
  --queries "${DATA_DIR}/must_have_labels.sparql" \
  --output-dir "${RESULTS_DIR}/verify"
VERIFY_RC=$?
set -e
echo "(verify exit code = ${VERIFY_RC}; non-zero means violation found)"

echo "== report (QC report) =="
set +e
robot report \
  --input "${RESULTS_DIR}/merged.owl" \
  --output "${RESULTS_DIR}/report.tsv"
REPORT_RC=$?
set -e
echo "(report exit code = ${REPORT_RC}; non-zero means violation found)"

echo "== filter (keep only Heart & part_of) =="
robot filter \
  --input "${RESULTS_DIR}/merged.owl" \
  --term-file "${DATA_DIR}/seeds.txt" \
  --output "${RESULTS_DIR}/filtered.owl"

echo "== extract (SLME: BOT, TOP, STAR) =="
robot extract --method BOT  --input "${RESULTS_DIR}/merged.owl" --term http://example.com/Heart --output "${RESULTS_DIR}/extract_bot.owl"
robot extract --method TOP  --input "${RESULTS_DIR}/merged.owl" --term http://example.com/Organ --output "${RESULTS_DIR}/extract_top.owl"
robot extract --method STAR --input "${RESULTS_DIR}/merged.owl" --term http://example.com/Heart --output "${RESULTS_DIR}/extract_star.owl"

echo "== extract (MIREOT with intermediates minimal/none) =="
robot extract --method MIREOT \
  --input "${RESULTS_DIR}/merged.owl" \
  --upper-term http://example.com/Organ \
  --lower-term http://example.com/Heart \
  --intermediates minimal \
  --output "${RESULTS_DIR}/extract_mireot_minimal.owl"

robot extract --method MIREOT \
  --input "${RESULTS_DIR}/merged.owl" \
  --upper-term http://example.com/Organ \
  --lower-term http://example.com/Heart \
  --intermediates none \
  --output "${RESULTS_DIR}/extract_mireot_none.owl"

echo "== extract (subset method) =="
robot extract --method subset \
  --input "${RESULTS_DIR}/merged.owl" \
  --term http://example.com/Organ \
  --term http://example.com/Heart \
  --output "${RESULTS_DIR}/extract_subset.owl"

echo "== extract (imports include vs exclude) =="
robot extract --method BOT \
  --input "${DATA_DIR}/imports-nucleus.owl" \
  --term http://example.com/Mitochondrion \
  --imports exclude \
  --output "${RESULTS_DIR}/mito_exclude.owl"

robot extract --method BOT \
  --input "${DATA_DIR}/imports-nucleus.owl" \
  --term http://example.com/Mitochondrion \
  --imports include \
  --output "${RESULTS_DIR}/mito_include.owl"

echo "== remove (deprecated example & selectors) =="
# Add a fake deprecated axiom to demonstrate remove by pattern
cat > "${DATA_DIR}/depr.ttl" <<'TTL'
@prefix ex: <http://example.com/> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix rdfs:<http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
ex:Lung a owl:Class ; rdfs:label "Lung" ; owl:deprecated "true"^^xsd:boolean .
TTL
robot merge --input "${RESULTS_DIR}/merged.owl" --input "${DATA_DIR}/depr.ttl" --output "${RESULTS_DIR}/with_depr.owl"

robot remove \
  --input "${RESULTS_DIR}/with_depr.owl" \
  --select "owl:deprecated='true'^^xsd:boolean" \
  --output "${RESULTS_DIR}/removed_deprecated.owl"

echo "== remove (external axioms to create a 'base' subset) =="
robot remove \
  --input "${RESULTS_DIR}/with_depr.owl" \
  --base-iri http://example.com \
  --axioms external \
  --preserve-structure false \
  --trim false \
  --output "${RESULTS_DIR}/base_subset.owl"

echo "== rename (using mapping.tsv) =="
robot rename \
  --input "${RESULTS_DIR}/merged.owl" \
  --mapping "${DATA_DIR}/mapping.tsv" \
  --output "${RESULTS_DIR}/renamed.owl"

echo "== repair (auto-fix modeling issues where possible) =="
robot repair \
  --input "${RESULTS_DIR}/renamed.owl" \
  --output "${RESULTS_DIR}/repaired.owl"

echo "== template (merge-before) =="
robot template --merge-before \
  --input "${RESULTS_DIR}/repaired.owl" \
  --template "${DATA_DIR}/template.csv" \
  --output "${RESULTS_DIR}/templated_merged.owl"

echo "== template (merge-after + save result AND chain annotate) =="
robot template --merge-after \
  --input "${RESULTS_DIR}/repaired.owl" \
  --template "${DATA_DIR}/template.csv" \
  --output "${RESULTS_DIR}/templated_result.owl" \
  annotate --annotation rdfs:comment "Templated terms merged" \
  --output "${RESULTS_DIR}/templated_after.owl"

echo "== template (ancestors) =="
robot template --ancestors \
  --input "${RESULTS_DIR}/repaired.owl" \
  --template "${DATA_DIR}/template.csv" \
  --ontology-iri "http://example.com/template_with_ancestors" \
  --output "${RESULTS_DIR}/templated_ancestors.owl"

echo "== validate-profile (EL) =="
robot validate-profile \
  --input "${RESULTS_DIR}/templated_after.owl" \
  --profile EL

echo "== python (embedded) =="
# Note: We already wrote add_comment.py; robot's python command executes it.
robot python \
  --input "${DATA_DIR}/base.owl" \
  --script "${DATA_DIR}/add_comment.py" \
  --output "${RESULTS_DIR}/python_out.owl"

echo "== unmerge (split merged ontology content) =="
robot unmerge \
  --input "${RESULTS_DIR}/templated_merged.owl" \
  --output "${RESULTS_DIR}/unmerge_out"

# (Optional) mirror – typically fetches remote imports (skip if offline)
# echo "== mirror (commented: requires remote IRIs) =="
# robot mirror --input some-importing-ontology.owl --directory imports/

echo "All done. Check the '${RESULTS_DIR}/' directory for outputs."
