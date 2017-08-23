# Photos

Photos (yay, awesome name) is a node web application to show beautilful and neat photos gallery.
But not only, it has been super optimized to do it fast! 
It scores 100/100 on Google PageSpeed Insights https://developers.google.com/speed/pagespeed/insights/.

# Demo

It's up and running here http://photos.solt.biz/potd.
Just check by yourself: https://developers.google.com/speed/pagespeed/insights/?url=http%3A%2F%2Fphotos.solt.biz%2Fpotd&tab=mobile.

# How to install

    $> git clone https://github.com/florentsolt/photos.git

Then, create a folder in the "uploads" folder, for example "uploads/1stgallery".
Finally run:

    $> ./bin/generate 1stgallery

If you are as lazy as me, you can also use the autcomplete of your shell and type "up" then <Tab> key, then type "1st" and <Tab>:

    $> ./bin/generate uploads/1stgallery

You gallery is ready!

Edit the config file (copy the config-dist.js file).
And run the web app:

    $> ./bin/www

Enjoy!