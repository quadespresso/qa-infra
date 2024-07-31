//
// Original script taken from repo: https://github.com/MirantisContainers/kddtest
// the purpose of which is to created pods and record the amount of time it takes
// for the pod to be allocated an IP address to give an indication of Calico's
// (the CNI) performance
//
import http from 'k6/http';
import { check, sleep, fail } from 'k6';
import { randomString } from 'https://jslib.k6.io/k6-utils/1.1.0/index.js';

const NAMESPACE_PREFIX = "test-k6-";
export let NAMESPACE;

export let options = {
    tlsAuth: [
        {
            cert: open(`${__ENV.DOCKER_CERT_PATH}/cert.pem`),
            key: open((`${__ENV.DOCKER_CERT_PATH}/key.pem`)),
        },
    ],
    stages: [
        { duration: '60s', target: __ENV.VU },
        { duration: '5s', target: 0 },
    ],
    insecureSkipTLSVerify: true,
    teardownTimeout: '180s',
};

// Get the namespace created for the run
export function setup() {
    const baseUrl = __ENV.BASE_URL;
    if (baseUrl.endsWith("/")) {
        baseUrl = baseUrl.slice(0, -1);
    }

    const clusterIdMatch = baseUrl.match(/https:\/\/([^.-]+)/);
    let clusterId = "id-not-found";
    if (clusterIdMatch) {
        clusterId = clusterIdMatch[1];
    }
    console.debug(`Extracted clusterId: ${clusterId}`);

    // Construct the namespace
    NAMESPACE = NAMESPACE_PREFIX + clusterId;
    console.debug(`Constructed NAMESPACE: ${NAMESPACE}`);

    const createNamespacePayload = JSON.stringify({
        apiVersion: 'v1',
        kind: 'Namespace',
        metadata: {
            name: NAMESPACE
        }
    });

    const headers = { 'Content-Type': 'application/json' };
    const url = `${baseUrl}/api/v1/namespaces`;

    const res = http.post(url, createNamespacePayload, { headers: headers });
    check(res, {
        'namespace created': (r) => r.status === 201,
    });

    return { NAMESPACE };
}

export default function (data) {
    const uniqueNamespace = data.NAMESPACE;
    
    let baseUrl = __ENV.BASE_URL; // Replace with your Kubernetes API server address
    if (baseUrl.endsWith("/")) {
        baseUrl = baseUrl.slice(0, -1);
    }
  
    const POD_NAME = `test-pod-${__VU}-${__ITER}`;
    // Simulate pod creation
    let createPodPayload = JSON.stringify({
        apiVersion: 'v1',
        kind: 'Pod',
        metadata: {
            name: POD_NAME,
            namespace: uniqueNamespace
        },
        spec: {
            containers: [{
                name: 'nginx',
                image: 'nginx:latest',
                ports: [{ containerPort: 80 }]
            }]
        }
    });

    let headers = { 'Content-Type': 'application/json' };
    let url = `${baseUrl}/api/v1/namespaces/${uniqueNamespace}/pods`
    console.debug(`url: ${url}`)
    const start = Date.now();

    let createPodRes = http.post(url, createPodPayload, { headers: headers });
    let pod = JSON.parse(createPodRes.body)

    console.debug(`Creating pod Iteration: ${__ITER}`);
    console.debug(`Status Code: ${createPodRes.status}`);
    console.debug(`Status Code: ${createPodRes.body}`);
    console.debug(`Response Time: ${createPodRes.timings.duration} ms`);

    check(createPodRes, {
        'create pod status is 201': (r) => r.status === 201,
    });


    //loop until get ip
    url = `${baseUrl}/api/v1/namespaces/${uniqueNamespace}/pods/${POD_NAME}`;
    let podHasIP = false;

    let count = 0;
    while (!podHasIP) {
        const res = http.get(url, headers);
        count++;

        // Check if the response status is 200 (OK)
        check(res, {
            'get pod is status 200': (r) => r.status === 200,
        });

        if (res.status === 200) {
            const pod = JSON.parse(res.body);

            // Check if the pod has an IP address assigned
            podHasIP = pod.status && pod.status.podIP;
            if (podHasIP) {
                console.debug(`Pod ${POD_NAME} IP address: ${pod.status.podIP} had to try ${count} times`);
                break;
            }
        } else {
            console.error(`Failed to get pod status. Status code: ${res.status}`);
            fail('Failed to retrieve pod status');
        }
        sleep(0.1)
    }

    if (!podHasIP) {
        fail(`Pod ${POD_NAME} did not get an IP address.`);
    }

    const end = Date.now();
    const timeTaken = end - start;  // Time taken in milliseconds
    console.info(`time to get ip: ${timeTaken}ms`)


    // Simulate pod deletion
    let deletePodRes = http.del(`${baseUrl}/api/v1/namespaces/${uniqueNamespace}/pods/${POD_NAME}`, null, { headers: headers });

    console.debug(`Deleting pod Iteration: ${__ITER}`);
    console.debug(`Status Code: ${deletePodRes.status}`);
    console.debug(`Response Time: ${deletePodRes.timings.duration} ms`);
    check(deletePodRes, {
        'delete pod status is 200': (r) => r.status === 200,
    });

    sleep(1); // Wait for a second before the next iteration
}

// Clean up function after the load test
export function teardown(data) {

    const uniqueNamespace = data.NAMESPACE;

    let baseUrl = __ENV.BASE_URL;
    if (baseUrl.endsWith("/")) {
        baseUrl = baseUrl.slice(0, -1);
    }

    const deleteNamespaceUrl = `${baseUrl}/api/v1/namespaces/${uniqueNamespace}`;

    console.debug(`Attempting to delete namespace: ${uniqueNamespace}`);
    const res = http.del(deleteNamespaceUrl);

    check(res, {
        'namespace deleted': (r) => r.status === 200,
    });

    if (res.status !== 200) {
        console.error(`Failed to delete namespace: ${uniqueNamespace}. Status code: ${res.status}`);
    } else {
        console.info(`Successfully deleted namespace: ${uniqueNamespace}`);
    }
}
