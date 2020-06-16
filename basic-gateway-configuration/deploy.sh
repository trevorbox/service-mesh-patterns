#!/bin/bash

oc new-project bookinfo

helm template -n bookinfo . | oc apply -f -