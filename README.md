# DataGrid-Perfromance-Run
Space where we will setup DataGrid 8.4 on Azure VMs and run some performance tests

## Compute

For this test run I am using 5 Azure virtual machines with 4 vCPUs and 64GB of RAM. I am also attaching 2 TB of SSD for caching evicted entries. Idea is to cache entries when we get our OFF_HEAP memory full.

## Setting up environment for DG servers

Using latest RHEL 9.2 with my active subscription and java-17-openjdk-devel using yum.

### Register your VM with RHEL Subscription 

This will register your VM to Red Hat Cloud access program and if Simple Cloud Access is enabled then you wont need to attach any subscription.

```bash
sudo subscription-manager register
```
You can verify status in two ways

```bash
sudo subscription-manager status
```
or 
```bash
sudo subscription-manager identity
```
### Install Java JDK 17 and configuring required JAVA_HOME

If your VMs is registered successfully then you can use yum to install Java.

```bash
sudo yum install java-17-openjdk-devel
```
Verify
```bash
java -version
```
And then add Java Home permanently
```bash
sudo vi /etc/bashrc
```
and add below two line at the bottom on the bashrc

```bash
export JAVA_HOME=/usr/lib/jvm/jre
export PATH=$JAVA_HOME/bin:$PATH
```

Source and Verify if JAVA_HOME is set
```bash
source /etc/bashrc
printenv | grep JAVA_HOME
```

### Mount SSDs to Cache data which gets evicted when OFF_HEAP gets full

Before proceeding make sure that you have SSDs attached to your VM instances. In my example I used 2TB Premium SSD from Azure while creating VMs.

There are many ways you can mount the disk but I followed the procedure outlined here specifically for Azure:
https://katarinaslama.github.io/2020/02/26/mounting-extra-storage-on-your-VM/

Make sure you verify that correct user permissions are set before proceeding.

### Download and Install DataGrid package

Here I am using DataGrid 8.4. The binaries are available on the [RH downloads](https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?product=data.grid&downloadType=distributions) website.

Copy bits to your local home directory and unzip them.
```bash
unzip redhat-datagrid-8.4.0-server.zip
```
Go into unziped folder and create a user for DataGrid
```bash
./bin/cli.sh user create developer -p developer -g admin
```

Lets start the server lcoally
```bash
./bin/server.sh -b 0.0.0.0 &
```

Verify if server started at localhost
```bash
curl --digest http://develoepr:developer@localhost:11222/rest/v2/security/user/acl -v
```

If you see some content at the bottom of your screen then we are a step closer to our goal. Cheers!

### Opening up Ports and Firewall for enabling connection between DataGrid VMs

As you can notice in above curl command console is accessible at 11222 port and server starts at 7800 port. So we will need to open up both ports in firewall and on Azure networking security group on Azure Portal. And these ports need to be added to both ingress and egress rules for our VMs to comminicate with their cluster members.

After you add firewall rules to allow ports 11222 and 7800 on Azure portal for ingress and egress, proceed below to open up firewall from your VM.

```bash
sudo firewall-cmd --zone=public --permanent --add-service=http && \
sudo firewall-cmd --zone=public --permanent --add-port 11222/tcp && \
sudo firewall-cmd --zone=public --permanent --add-port 7800/tcp && \
sudo firewall-cmd --reload && \
sudo firewall-cmd --list-all
```

Now you can verify if above settings were applied correctly by loading console on your browser using public IP and port 11222.

### Let our DataGrid servers know about their peers

Now, we will need to let our DataGrid VMs notify of other VMs by modifying infinispan.xml file and adding below block.

Replace localhost to your VM's IP or hostnames. Remember hostnames and IPs should be reachable from other nodes.

Locate infinispan.xml file inside your unziped folder
```bash
vi server/conf/infinispan.xml
```

Update file with below block, which defined static members which we specify as initil_hosts and a cache name 'respCache'.

```xml
   <jgroups>
      <stack name="myazure" extends="tcp">
         <TCPPING initial_hosts="10.0.3.4[7800],10.0.0.8[7800],10.1.2.3[7800],10.1.2.4[7800],10.1.3.3[7800]" port_range="0" stack.combine="REPLACE" stack.position="MPING"/>
      </stack>
   </jgroups>
   <cache-container name="default" statistics="true">
      <transport cluster="${infinispan.cluster.name:cluster}" stack="${infinispan.cluster.stack:myazure}" node-name="${infinispan.node.name:}"/>
      <security>
         <authorization/>
      </security>
      <replicated-cache name="respCache" mode="ASYNC" statistics="true">
         <encoding>
            <key media-type="application/x-protostream"/>
            <value media-type="application/x-protostream"/>
         </encoding>
         <memory storage="OFF_HEAP" max-size="48GB" when-full="REMOVE"/>
         <persistence>
            <file-store />
         </persistence>
         <global-state>
            <persistent-location path="/data/dg"/>
         </global-state>
      </replicated-cache>
   </cache-container>
```

And now lets start our servers again and verify if you see cluster members in the console or logs as in this [screen shot](image.png)

### Add a load balancer to run benchmark tool

You can either user Azurel LB here or bring your own. I went through easy path of using Azure LB.

One thing to note for Azure LB is to make sure you have your VM IPs in Standard SKU and not in Basic SKU. Without having them in Standard SKU, you wont be able to add these VMs in backend pool for Load Balancer which was created in Standard SKU.

## Running Redis-Benchmark tool

Now, lets just setup benchmark tool locally and kick off our perfromance test.

### Install redis-benchmark tool locally

Somewhere in your local directory perfrom below operations to download, unzip and compile to generate redis-benchmark tool.

```bash
wget http://download.redis.io/releases/redis-7.0.5.tar.gz
tar xzf redis-7.0.5.tar.gz
cd src
make
```
Above will compile the source and generate tool under folder redis-benchmark under src folder.

### Run redis-benchmark tool

We will be running this tool with about 1 million requests and perfrom both SET and GET operation using a random key for every operation out of 1m possible keys with 120kb of payload.

```bash
./redis-benchmark -t set,get -d 120000 -r 1000000 -n 1000000 -h {lbIP} -p 11222 --user developer -a developer
```
After few minutes you should see results on your console with summary of test run.

for example:
```bash
SET Summary:
  throughput summary: 1228.53 requests per second
  latency summary (msec):
          avg       min       p50       p95       p99       max
       40.616     0.376    24.415    59.519   499.455  3000.319

GET Summary:
  throughput summary: 10417.86 requests per second
  latency summary (msec):
          avg       min       p50       p95       p99       max
        1.011     0.352     1.007     1.271     1.423   211.839
```

## Look at the results on Data Grid console

Log in to your console and you can browse the performance test statistics on console.


## Thank You and feel free to comment here or reach out if any questions!!!
















