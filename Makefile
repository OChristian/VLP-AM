env:
	$(source) ./sspenv
registry:
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

test:
	curl -i -I -u "${username}:${token}" \
	  https://securityservices.packages.broadcom.com/v2/ssp-db-initializer/manifests/4.1.2.2037

del:
	microk8s kubectl delete secret ssp-registrypullsecret -n ${NAMESPACE}
	microk8s kubectl delete secret ssp-infra-registrypullsecret -n ${NAMESPACE}
#	microk8s kubectl delete validatingwebhookconfiguration percona-xtradbcluster-webhook
#	microk8s kubectl patch clickhouseinstallation ssp-ssp-ch -n ssp -p '{"metadata":{"finalizers":[]}}' --type=merge
#	microk8s kubectl patch clickhousekeeperinstallations ssp-ssp-chk -n ssp   -p '{"metadata":{"finalizers":[]}}' --type=merge

nginx:
#	helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
	helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx

infra:
	helm install "infra-${RELEASENAME}" "${HELM_REPO}/ssp-infra" -n "${NAMESPACE}" \
	--set sspReleaseName="${RELEASENAME}" \
	--set clickhouse.enabled="true" \
#	--set db.existingSecret="ssp-ssp-db-pxc" \
	--set clickhouse.existingSecret="ssp-ssp-chcred" \
	--set ssp.deployment.size="demo" \
	--set hazelcast-enterprise.cluster.memberCount=1
ssp:
	helm upgrade --install "${RELEASENAME}" -n "${NAMESPACE}" "${HELM_REPO}/ssp" --set ssp.ingress.host="${SSP_FQDN}" --timeout=120m \
	--set global.ssp.registry.existingSecrets[0].name=ssp-registrypullsecret \
	--set ssp.global.ssp.registry.existingSecrets[0].name=ssp-registrypullsecret \
	--set ssp.deployment.size="demo" \
	--set ssp.db.sslMode="REQUIRED" \
	--set hazelcast-enterprise.cluster.memberCount=1