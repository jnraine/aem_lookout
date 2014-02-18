#!/bin/bash

VLT=/Users/jnraine/projects/cq/instances/author/crx-quickstart/opt/filevault/vault-cli-2.4.18/bin/vlt
WHERE_JCR_ROOT_AND_META_INF_IS=/tmp/playground
JCR_ROOT_PATH=/
CQ_HOST="http://localhost:4502"
CREDENTIALS="admin:cq4me"

$VLT --credentials $CREDENTIALS -v import $CQ_HOST/crx/-/jcr:root $WHERE_JCR_ROOT_AND_META_INF_IS $JCR_ROOT_PATH
