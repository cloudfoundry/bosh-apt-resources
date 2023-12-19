# How to use APT

wget -q -O - https://raw.githubusercontent.com/cloudfoundry/bosh-apt-resources/master/public.key | apt-key add -
echo "deb http://apt.ci.cloudfoundry.org stable main" | tee /etc/apt/sources.list.d/bosh-cloudfoundry.list

# Contribute
a github release that provides cli is easy to add
see ci/resources.yml