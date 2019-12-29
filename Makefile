.PHONY: all drop-cluster create-cluster x509-cert container-secret ingress-secret deployment endpoint load-balancer ingress
all:
	@echo See $(CURDIR)/$(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))
drop-cluster:
	@echo CLUSTER=${CLUSTER}
	@echo ZONE=${ZONE}
	@gcloud container clusters delete ${CLUSTER} --zone=${ZONE}
create-cluster:
	@echo CLUSTER=${CLUSTER}
	@echo MIN_NODE=${MIN_NODE}
	@echo MAX_NODE=${MAX_NODE}
	@echo ZONE=${ZONE}
	@gcloud container clusters create ${CLUSTER} --enable-autoupgrade --enable-autoscaling --min-nodes=${MIN_NODE} --max-nodes=${MAX_NODE} --zone=${ZONE}
x509-cert:
	@echo DAYS=${DAYS}
	@echo HOST=${HOST}
	@echo KEY_FILE=${KEY_FILE}
	@echo CERT_FILE=${CERT_FILE}
	@openssl req -x509 -nodes -days ${DAYS} -newkey rsa:2048 -keyout ${KEY_FILE} -out ${CERT_FILE} -subj "/CN=${HOST}/O=${HOST}"
container-secret:
	@kubectl create secret generic container-secret --from-file=rsakeys/nginx.crt --from-file=rsakeys/nginx.key
ingress-secret:
	@echo CRT_FILE=${CRT_File}
	@echo KEY_FILE=${KEY_FILE}
	@kubectl create secret tls ingress-secret --cert=${CRT_FILE} --key=${KEY_FILE}
endpoint:
##
## source template: template/api.yaml
## note:
##     Configure a credential of type API Keys for this endpoint, i.e., $${name}.endpoints.$${project_id}.cloud.goog
##     and pass key=$${credential} with requests for query, then it should work.
##          If a request without access key (credential) is sent, you will get the following forbidden message:
## {
##  "code": 3,
##  "message": "API key not valid. Please pass a valid API key.",
##  "details": [
##   {
##    "@type": "type.googleapis.com/google.rpc.DebugInfo",
##    "stackEntries": [],
##    "detail": "service_control"
##   }
##  ]
## }
##          If a request with wrong access key, for example, you forgot to configure API restrictions to allow traffic for this API,
##     or, you give a credential outside of this endpoint service, you will get the following questioning message:
## {                                                                                                     
##  "code": 7,                                                                                           
##  "message": "API $${name}.endpoints.$${project_id}.cloud.goog is invalid for the consumer project.",   
##  "details": [                                                                                         
##   {                                                                                                   
##    "@type": "type.googleapis.com/google.rpc.DebugInfo",                                               
##    "stackEntries": [],                                                                                
##    "detail": "service_control"                                                                        
##   }                                                                                                   
##  ]                                                                                                    
## }                                                                                                     
	@echo NAME=${NAME}
	@echo IP_ADDRESS=${IP_ADDRESS}
	@ temp_file=$$(mktemp) && mv $${temp_file} $${temp_file}.yaml && temp_file=$${temp_file}.yaml &&\
project_id=`gcloud config get-value project` &&\
gce_endpoint=${NAME}.endpoints.$${project_id}.cloud.goog &&\
< "template/api.yaml" sed -E "s/SERVICE_NAME/$${gce_endpoint}/g" | sed -E "s/IP_ADDRESS/${IP_ADDRESS}/g" > $${temp_file} &&\
#cat $${temp_file} &&\
gcloud endpoints services deploy $${temp_file} &&\
rm $${temp_file}
deployment:
	@ project_id=`gcloud config get-value project` &&\
gce_endpoint=${NAME}.endpoints.$${project_id}.cloud.goog &&\
< "template/apiservice.yaml" sed -E "s/SERVICE_NAME/$${gce_endpoint}/g" > "skaffold/kubernetes-manifests/apiservice.yaml" &&\
#cat "skaffold/kubernetes-manifests/apiservice.yaml" &&\
< "template/skaffold.yaml" sed -E "s/PROJECT_ID/$${project_id}/g" > "skaffold/skaffold.yaml" &&\
#cat "skaffold/skaffold.yaml" &&\
cd skaffold && skaffold run --default-repo=gcr.io/$${project_id}
load-balancer:
	@echo NAME=${NAME}
	@kubectl apply -f "template/load-balancer.yaml"
ingress:
	@ temp_file=$$(mktemp) && mv $${temp_file} $${temp_file}.yaml && temp_file=$${temp_file}.yaml &&\
project_id=`gcloud config get-value project` &&\
gce_endpoint=${NAME}.endpoints.$${project_id}.cloud.goog &&\
< "template/ingress.yaml" sed -E "s/INGRESS_NAME/$${gce_endpoint}/g" > $${temp_file} &&\
kubectl apply -f $${temp_file} &&\
rm $${temp_file}
