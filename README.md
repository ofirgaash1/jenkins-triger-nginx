copy the .sh script to RC local (or create a service that runs it on every restart).

it trigers a jenkins job on another ec2 machine.
the jenkins job uses ansible to update nginx on the first machine (the machine with the rc.local) and to update it's ip on route 53 (ofir.aws.cts.care)
