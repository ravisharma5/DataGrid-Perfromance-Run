# DataGrid-Perfromance-Run
Space where we will setup DataGrid 8.4 on Azure VMs and run some performance tests

## Compute

For this test run I am using 3 Azure virtual machines with 4 vCPUs and 16GB of RAM. I am also attaching 512 GB of SSD for caching purposes.

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
export PATH="$JAVA_HOME/bin:$PATH
```

Source and Verify if JAVA_HOME is set
```bash
source /etc/bashrc
printenv | grep JAVA_HOME
```

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
./bin/server.sh -b 0.0.0.0
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
sudo firewall-cmd --zone=public --permanent --add-service=http
sudo firewall-cmd --zone=public --permanent --add-port 11222/tcp
sudo firewall-cmd --zone=public --permanent --add-port 7800/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```

Now you can verify if above settings were applied correctly by loading console on your browser using public IP and port 11222.

### Let our DataGrid servers know about their peers

Now, we will need to let our DataGrid VMs notify of other VMs by modifying infinispan.xml file and adding below block.

Replace localhost to your VM's public IP or hostnames.

Locate infinispan.xml file inside your unziped folder
```bash
vi server/conf/infinispan.xml
```

Update file with below block:

```xml
   <jgroups>
      <stack name="myazure" extends="tcp">
         <TCPPING initial_hosts="localhost[7800],localhost[7800],localhost[7800]" port_range="3" stack.combine="REPLACE" stack.position="MPING"/>
      </stack>
   </jgroups>
```

And now lets start our servers again















