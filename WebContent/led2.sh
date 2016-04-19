#led light

cs /sys/class/gpio

echo 04 > export
echo "New ledout created"
cd gpio4
set out > direction
echo "GPIO3 set as output"
for i in 'seq 1 10';
do
 echo $i
 echo 1 > value
 sleep 1
 echo 0 > value
 sleep 1
done
echo 1 > value
