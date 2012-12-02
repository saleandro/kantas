var Kantas = {
  checkResponse: function(i, j) {
    var el = $('#word-'+i+'-'+j);
    if (el.val().toLowerCase().replace(/[-.,()&$#!\[\]{}"']/, '') == el.attr('data-value').toLowerCase().replace(/[-.,()&$#!\[\]{}"']/, '')) {
      var next = $(':input:eq(' + ($(":input").index(el) + 1) + ")");
      el.replaceWith(el.attr('data-value'));
      if ($('input').length == 0) {
        $('.alert-success').show();
      } else {
        next.focus();
      }
    } else {
      if (el.val() != '') {
        el.addClass('error');
      }
    }
  },

  renderTrack: function(artist, title) {
    var width = 250;
    var height = 250;
    var lyrics = $('p.lyrics-with-time');
    var lastTime = 0;
    var track = window.tomahkAPI.Track(title, artist, {
      width:width,
      height:height,
      disabledResolvers: [  ],
      handlers: {
        onloaded: function() {
        },
        onended: function() {
        },
        onplayable: function() {
        },
        onresolved: function(resolver, result) {
        },
        ontimeupdate: function(timeupdate) {
          // if (timeupdate['currentTime'] > 0) {
          //   for (var i=0; i < lyrics.length; i++) {
          //     var el = $(lyrics[i]);
          //     var time = parseFloat(el.attr('data-time'));
          //     console.log("time:"+ time + " <=  curTime:"+timeupdate['currentTime'] + ">= lastTIme:"+lastTime);
          //     if ((time <=  timeupdate['currentTime']) && (time >= lastTime)) {
          //       if (i > 0) {
          //         $(lyrics[i-1]).removeClass('highlight');
          //       }
          //       lastTime = timeupdate['currentTime'];
          //       el.addClass('highlight');
          //       break;
          //     }
          //   }
          // }
        }
      }
    });
    var playerEl = document.getElementById("player");
    playerEl.insertBefore(track.render(), playerEl.childNodes[0]);
  }
};