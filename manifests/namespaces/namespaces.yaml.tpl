---
apiVersion: v1
kind: Namespace
metadata:
  name: __CALLER_NAMESPACE__
  labels:
    pki-lab-owned: "true"
    component: applications
---
apiVersion: v1
kind: Namespace
metadata:
  name: __CALLING_NAMESPACE__
  labels:
    pki-lab-owned: "true"
    component: applications
