for i in `ps -u bilek u | grep perl | awk '{ print $2; }'`; do kill -9 $i; done
