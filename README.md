# dbench
Benchmark Kubernetes persistent disk volumes with `fio`: Read/write IOPS, bandwidth MB/s and latency.

# Usage
Create `./sensitive-data.sh` with following data, where XXX is your docker login and YYYY your docker repository

```bash
export DOCKER_USER=XXX
export DOCKER_IMAGE=YYYY/dbench:latest

```

Run `./apply-dbench-all-storage-classes.sh`
When deployed, for each available storage class the `Dbench-${STORAGE_CLASS}` Kubernetes Job will create and will make following steps:
    * provision a Persistent Volume of `1000Gi` (default) using `storageClassName: ${STORAGE_CLASS}`
    * run a series of `fio` tests on the newly provisioned disk
    * currently there are 9 tests, 15s per test - total runtime for each storage class is ~2.5 minutes
At the end of all tests, you'll see a summary for each storage class in <storage_class>.log that looks similar to this:

```
==================
= Dbench Summary =
==================
Random Read/Write IOPS: 75.7k/59.7k. BW: 523MiB/s / 500MiB/s
Average Latency (usec) Read/Write: 183.07/76.91
Sequential Read/Write: 536MiB/s / 512MiB/s
Mixed Random Read/Write IOPS: 43.1k/14.4k
```
6. Once the tests are finished, clean up using: `kubectl delete -f dbench.yaml` and that should deprovision the persistent disk and delete it to minimize storage billing.

## Notes / Troubleshooting

* If the Persistent Volume Claim is stuck on Pending, it's likely you didn't specify a valid Storage Class. Double check using `kubectl get storageclasses`. Also check that the volume size of `1000Gi` (default) is available for provisioning.
* It can take some time for a Persistent Volume to be Bound and the Kubernetes Dashboard UI will show the Dbench Job as red until the volume is finished provisioning.
* It's useful to test multiple disk sizes as most cloud providers price IOPS per GB provisioned. So a `4000Gi` volume will perform better than a `1000Gi` volume. Just edit the yaml, `kubectl delete -f dbench.yaml` and run `kubectl apply -f dbench.yaml` again after deprovision/delete completes.
* A list of all `fio` tests are in [docker-entrypoint.sh](https://github.com/altinity/dbench/blob/master/docker-entrypoint.sh).

## Contributors

* [Lee Liu (LogDNA)](https://github.com/leeliu)
* [Alexis Turpin](https://github.com/alexis-turpin)
* [Eugene Klimov](https://github.com/Slach)

## License

* MIT
