#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="data"
mkdir -p "$DATA_DIR"

# --- MINI ONTOLOGIES & FILES ---------------------------------------------

# 1) A tiny base ontology in Turtle (classes, a property, and basic axioms)
cat > "${DATA_DIR}/base.ttl" <<'TTL'
@prefix ex: <http://example.com/> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix owl:  <http://www.w3.org/2002/07/owl#> .
@prefix xsd:  <http://www.w3.org/2001/XMLSchema#> .

ex:Ontology a owl:Ontology .

# Classes
ex:Organ      a owl:Class ; rdfs:label "Organ" .
ex:Heart      a owl:Class ; rdfs:label "Heart" .
ex:Lung       a owl:Class ; rdfs:label "Lung" .
ex:Organism   a owl:Class ; rdfs:label "Organism" .

# Object property
ex:part_of a owl:ObjectProperty ; rdfs:label "part of" ;
  rdfs:domain ex:Organ ; rdfs:range ex:Organism .

# Basic axioms
ex:Heart rdfs:subClassOf ex:Organ .
ex:Lung  rdfs:subClassOf ex:Organ .
TTL

# 2) A second tiny ontology to show merge/diff
cat > "${DATA_DIR}/extra.ttl" <<'TTL'
@prefix ex: <http://example.com/> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix owl:  <http://www.w3.org/2002/07/owl#> .

ex:Ontology a owl:Ontology .

ex:Kidney a owl:Class ; rdfs:label "Kidney" ;
  rdfs:subClassOf ex:Organ .
TTL

# 3) A small imported ontology and an "imports wrapper" to demo imports include/exclude
cat > "${DATA_DIR}/nucleus.ttl" <<'TTL'
@prefix ex: <http://example.com/> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix owl:  <http://www.w3.org/2002/07/owl#> .
@prefix xsd:  <http://www.w3.org/2001/XMLSchema#> .

<http://example.com/nucleus> a owl:Ontology .

ex:IntracellularMembraneBoundedOrganelle a owl:Class ;
  rdfs:label "intracellular membrane-bounded organelle" .

ex:Mitochondrion a owl:Class ;
  rdfs:label "mitochondrion" ;
  rdfs:subClassOf ex:IntracellularMembraneBoundedOrganelle .
TTL

cat > "${DATA_DIR}/imports-nucleus.ttl" <<'TTL'
@prefix ex: <http://example.com/> .
@prefix owl:  <http://www.w3.org/2002/07/owl#> .

<http://example.com/imports-nucleus> a owl:Ontology ;
  owl:imports <file:./data/nucleus.ttl> .

# Local assertion just to show the difference between include/exclude
ex:Mitochondrion a owl:Class .
TTL

# 4) Seed list for extract/filter/remove
cat > "${DATA_DIR}/seeds.txt" <<'EOF'
http://example.com/Heart
http://example.com/part_of
EOF

# 5) Mapping file for rename
cat > "${DATA_DIR}/mapping.tsv" <<'TSV'
old_id	new_id
http://example.com/Organ	http://example.com/OrganStructure
http://example.com/Lung	http://example.com/PulmonaryOrgan
TSV

# 6) SPARQL query: find missing labels
cat > "${DATA_DIR}/missing_labels.sparql" <<'SPARQL'
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT ?entity WHERE {
  ?entity a ?type .
  FILTER NOT EXISTS { ?entity rdfs:label ?l }
}
SPARQL

# 7) SPARQL verify: ensure every class has a label (fail when result non-empty)
cat > "${DATA_DIR}/must_have_labels.sparql" <<'SPARQL'
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
ASK {
  ?entity a ?type .
  FILTER NOT EXISTS { ?entity rdfs:label ?l }
}
SPARQL

# 8) Python script example (will add a comment on the ontology)
cat > "${DATA_DIR}/add_comment.py" <<'PY'
from org.obolibrary.robot import IOHelper
from org.semanticweb.owlapi.model import IRI
from org.semanticweb.owlapi.model import OWLAnnotationProperty
from org.semanticweb.owlapi.apibinding import OWLManager

ontology = IOHelper().loadOntology("data/base.owl")
factory = OWLManager.getOWLDataFactory()
prop = factory.getRDFSComment()
value = factory.getOWLLiteral("Added via ROBOT python command")
ann = factory.getOWLAnnotation(prop, value)
manager = ontology.getOWLOntologyManager()
manager.applyChange(org.semanticweb.owlapi.model.AddOntologyAnnotation(ontology, ann))
IOHelper().saveOntology(ontology, "results/python_commented.owl")
PY

# 9) Template CSV (consistent with our later demo—individuals relate to individuals)
cat > "${DATA_DIR}/template.csv" <<'CSV'
ID,LABEL,TYPE,SC %,EC %,DC %,A rdfs:comment,DOMAIN,RANGE,CHARACTERISTIC,I part_of,TI %,DI %
ID,LABEL,TYPE,SC %,EC %,DC %,A rdfs:comment,DOMAIN,RANGE,CHARACTERISTIC,I part_of,TI %,DI %
EX:0001,Organ,class,SC %,,"",Top-level organ class,,,,,,
EX:0002,Heart,class,Organ,EC 'Organ' and part_of some EX:0004,DC EX:0003,Heart is an organ that is part_of some organism,,,,,,
EX:0003,Lung,class,EX:0001,,DC EX:0002,Respiratory organ,,,,,,
EX:0004,Organism,class,,,,"Whole organism (host) class",,,,,,
EX:part_of,part of,object property,,,"",Parthood relation (object property),EX:0001,EX:0004,transitive,,,,
EX:ind3,MyBody,individual,,,,"Concrete individual of an Organism",,,,"TI EX:0004",
EX:ind1,MyHeart,individual,,,,"Concrete individual of a Heart","",,"",EX:ind3,TI EX:0002,EX:ind2
EX:ind2,MyLung,individual,,,,"Concrete individual of a Lung","",,"",EX:ind3,TI EX:0003,EX:ind1
CSV
