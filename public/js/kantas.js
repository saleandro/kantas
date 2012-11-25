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
    var width = 200;
    var height = 200;
    var lyrics = $('p.lyrics-with-time');
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
          console.log(timeupdate);
          $('p').removeClass('highlight');
          console.log(timeupdate['currentTime']);
          // var line = $('#t'+timeupdate['currentTime']);
          // if (line) {
          //   line.addClass('highlight');
          // }
        }
      }
    });
    var playerEl = document.getElementById("player");
    playerEl.insertBefore(track.render(), playerEl.childNodes[0]);
  }
};