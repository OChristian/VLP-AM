env:
	$(source) ./sspenv
secrets:
	microk8s kubectl create secret docker-registry ssp-registrypullsecret -n ${NAMESPACE} \
		--docker-server="https://securityservices.packages.broadcom.com/" \
		--docker-username="${username}" \
		--docker-password="${token}" \
		--docker-email="christian.oberle@broadcom.com"

	microk8s kubectl create secret docker-registry ssp-infra-registrypullsecret -n ${NAMESPACE} \
		--docker-server="https://securityservices.packages.broadcom.com/" \
		--docker-username="${username}" \
		--docker-password="${token}" \
		--docker-email="christian.oberle@broadcom.com"

	microk8s kubectl create secret docker-registry ssp-hazelcast-registrypullsecret -n ${NAMESPACE} \
		--docker-server="https://securityservices.packages.broadcom.com/" \
		--docker-username="${username}" \
		--docker-password="${token}" \
		--docker-email="christian.oberle@broadcom.com"

mek:
	microk8s kubectl get secret ssp-ssp-keys-mek -n ssp -o jsonpath="{.data.mek\.key}" | base64 --decode; echo
test:
	curl -i -I -u "${username}:${token}" \
	  https://securityservices.packages.broadcom.com/v2/ssp-db-initializer/manifests/4.1.2.2037

del:
	microk8s kubectl delete secret ssp-registrypullsecret -n ${NAMESPACE}
	microk8s kubectl delete secret ssp-infra-registrypullsecret -n ${NAMESPACE}
#	microk8s kubectl delete validatingwebhookconfiguration percona-xtradbcluster-webhook
#	microk8s kubectl delete pvc datadir-ssp-ssp-db-pxc-0 -n ${NAMESPACE}
#	microk8s kubectl delete secret ssp-ssp-db-pxc internal-ssp-ssp-db ssp-ssp-chcred -n ${NAMESPACE}
#	microk8s kubectl patch clickhouseinstallation ssp-ssp-ch -n ssp -p '{"metadata":{"finalizers":[]}}' --type=merge
#	microk8s kubectl patch clickhousekeeperinstallations ssp-ssp-chk -n ssp   -p '{"metadata":{"finalizers":[]}}' --type=merge

envoy:
	helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
		--version v0.0.0-latest -n envoy-gateway-system --create-namespace

infra:
	helm install "infra-${RELEASENAME}" "${HELM_REPO}/ssp-infra" -n "${NAMESPACE}" \
	--set sspReleaseName="${RELEASENAME}" \
	--set clickhouse.enabled="true" \
#	--set db.existingSecret="ssp-ssp-db-pxc" \
	--set clickhouse.existingSecret="ssp-ssp-chcred" \
	--set ssp.deployment.size="demo" \
	--set hazelcast-enterprise.cluster.memberCount=1
ssp:
	helm upgrade --install "${RELEASENAME}" -n "${NAMESPACE}" "${HELM_REPO}/ssp" --timeout=120m \
	--set global.ssp.registry.existingSecrets[0].name=ssp-registrypullsecret \
	--set ssp.global.ssp.registry.existingSecrets[0].name=ssp-registrypullsecret \
	--set ssp.deployment.size="demo" \
	--set ssp.db.sslMode="REQUIRED" \
	--set hazelcast-enterprise.cluster.memberCount=1 \
	--set ssp.ingress.host="${SSP_FQDN}" \
	--set ssp.ingress.type="gatewayapi" \
	--set ssp.ingress.gatewayApi.gatewayClassName="envoy-gateway-class" \
	--set ssp.ingress.gatewayApi.createGateway=true \
	--set ssp.ingress.gatewayApi.createBackendTLSPolicy=true \
	--set ssp.ingress.tls.generateSelfSignedCert=true \
	--set ssp.ingress.mgmt.generateSelfSignedCert=true