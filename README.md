# Azure CLI DevTestLabs Gateway 'lab-gateway' Extension

This extension allows you to configure labs to use a remote desktop gateway to ensure secure access to lab virtual machines (VMs) without exposing the RDP port. Once configured, DevTestLabs changes the behavior of the lab VMs Connect button to generate a machine-specific RDP with a temporary authentication token from the gateway service.

This approach adds security by alleviating the need to have lab VMs RDP port exposed to the internet, instead tunneling RDP traffic over HTTPS. This article walks through an example on how to set up a lab that uses token authentication to connect to lab machines.

## Install the 'lab-gateway' Extension

To install the Azure CLI TeamCloud extension, simply run the following command:

```sh
az extension add -y --source https://github.com/colbylwilliams/lab-gateway/releases/latest/download/lab_gateway-0.4.0-py2.py3-none-any.whl
```

## Deploy a Gateway

To create/deploy a new gateway, use the following command:

```sh
az lab-gateway create -g ResourceGroup -l eastus \
    --admin-username azureuser \
    --admin-password Secure1! \
    --ssl-cert /path/to/SSLCertificate.pfx \
    --ssl-cert-password DontRepeatPasswords1 \
    --auth-msi /path/to/RDGatewayFedAuth.msi \
```

> Run `az lab-gateway create -h` for more help.

### Prerequisites

There are two required prerequisites to deploy the remote desktop gateway service; an SSL certificate, and the pluggable token authentication module installer. Details for both are below.

#### TLS/SSL Certificate

The solution creates an App Gateway in front of the RDG scale set that must be configured with a TLS/SSL certificate to handle HTTPS traffic. The certificate must match the fully qualified domain name (FQDN) that will be used for the gateway service. Wild-card TLS/SSL certificates will not work.

Specifically, you'll need:

- A SSL certificate matching the fully qualified domain name (FQDN) that will be used for the gateway service from a public certificate authority exported to a .pfx or .p12 (public/private) file
- The password used when exporting the SSL certificate

You'll also need to create a DNS record that points the FQDN to the Azure Public IP address of the gateway service load balancer. Find more details on this in the [Configure DNS](#configure-dns) section below.

#### RDGatewayFedAuth.msi

Secondly, you'll need the RDGatewayFedAuth pluggable authentication module that supports token authentication for the remote desktop gateway. RDGatewayFedAuth comes with System Center Virtual Machine Manager (VMM) images.

- If you have an MSDN account, you can download the latest System Center Virtual Machine Manager .iso archive [here](https://my.visualstudio.com/Downloads?q=System%20Center%20Virtual%20Machine%20Manager%202019&pgroup=)
- Extract the archive and find the retrieve the file from: `System Center Virtual Machine Manager > amd64 > Setup > msi > RDGatewayFedAuth.msi`

## Remote Desktop Gateway Terms

By using this template, you agree to the [Remote Desktop Gateways Terms](https://www.microsoft.com/en-us/licensing/product-licensing/products).

For further information, refer to [Remote Gateway](https://aka.ms/rds) and [Deploy your Remote Desktop environment](https://docs.microsoft.com/en-us/windows-server/remote/remote-desktop-services/rds-deploy-infrastructure).
