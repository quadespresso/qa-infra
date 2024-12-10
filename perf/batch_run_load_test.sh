# This file is included as an example as to how you can batch
# load test runs for a given cluster
REPORT_DIR=/tmp/mke_load_tests
if [ -z "$MKE_URL" ]; then
  read -p "Enter MKE URL: " MKE_URL
fi
MKE_URL="${MKE_URL%*/}"

if [ -z "$MKE_PASSWORD" ]; then
  read -s -p "Enter MKE password for user [admin]: " MKE_PASSWORD
  echo
fi
./run_load_test.sh -l xsmall --pods-per-node 100 --user-num 20 50 100 150 200 --mke-url $MKE_URL --mke-password $MKE_PASSWORD --report-dir $REPORT_DIR
./run_load_test.sh -l xsmall --pods-per-node 250 --user-num 20 50 100 150 200 --mke-url $MKE_URL --mke-password $MKE_PASSWORD --report-dir $REPORT_DIR
# ./run_load_test.sh -l xsmall --pods-per-node 500 --user-num 20 50 100 150 200 --mke-url $MKE_URL --mke-password $MKE_PASSWORD --report-dir $REPORT_DIR
