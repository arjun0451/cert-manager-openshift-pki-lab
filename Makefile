.PHONY: help prereqs root-ca intermediate verify-pki namespaces issuer certs verify-certs deploy verify-mtls edge-route verify-edge-route clean-edge-route trust-manager trustbundle-mtls verify-trustbundle-mtls clean-trustbundle-mtls render validate test bootstrap all clean
help:
	@echo 'make bootstrap (or make all) - build PKI, configure cert-manager, deploy and verify bidirectional mTLS'
	@echo 'make clean - remove only resources created by this lab'
prereqs:
	@command -v openssl >/dev/null && command -v oc >/dev/null
root-ca:
	@scripts/00_generate_root_ca.sh
intermediate:
	@scripts/01_generate_intermediate_ca.sh
verify-pki:
	@scripts/02_verify_chain.sh
namespaces:
	@scripts/03_create_namespaces.sh
issuer:
	@scripts/04_import_intermediate_secret.sh
	@scripts/05_create_clusterissuer.sh
certs:
	@scripts/06_create_certificates.sh
verify-certs:
	@scripts/07_verify_certificates.sh
deploy:
	@scripts/08_deploy_caller_nginx.sh
	@scripts/09_deploy_calling_nginx.sh
verify-mtls:
	@scripts/10_verify_mtls.sh
edge-route:
	@scripts/11_deploy_edge_route.sh
verify-edge-route:
	@scripts/12_verify_edge_route.sh
clean-edge-route:
	@scripts/13_cleanup_edge_route.sh
trust-manager:
	@oc apply -f manifests/trustbundle/00-trustmanager.yaml
trustbundle-mtls:
	@scripts/14_deploy_trustbundle_mtls.sh
verify-trustbundle-mtls:
	@scripts/15_verify_trustbundle_mtls.sh
clean-trustbundle-mtls:
	@scripts/16_cleanup_trustbundle_mtls.sh
render:
	@RENDER_OFFLINE=true scripts/render_manifests.sh
validate: render
	@RENDER_OFFLINE=true scripts/validate.sh
test:
	@bash tests/test_common.sh
	@bash tests/test_render.sh
bootstrap:
	@$(MAKE) prereqs
	@$(MAKE) root-ca
	@$(MAKE) intermediate
	@$(MAKE) verify-pki
	@$(MAKE) namespaces
	@$(MAKE) issuer
	@$(MAKE) certs
	@$(MAKE) verify-certs
	@$(MAKE) deploy
	@$(MAKE) verify-mtls
all: bootstrap
clean:
	@./cleanup.sh
