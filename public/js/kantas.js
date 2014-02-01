var KantasCompleteLyrics = {
  checkResponse: function(i, j) {
    var el = $('#word-'+i+'-'+j);
    if (el.val() == el.attr('data-value')) {
      var next = $(':input:eq(' + ($(":input").index(el) + 1) + ")");
      el.replaceWith("<span class='success'>"+el.attr('data-show')+'</span>');
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
      disabledResolvers: [ 'spotify' ],
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
          if (timeupdate['currentTime'] > 0) {
             for (var i=0; i < lyrics.length; i++) {
               var el = $(lyrics[i]);
               var time = parseFloat(el.attr('data-time'));
               if ((time <= timeupdate['currentTime']) && (time >= lastTime)) {
                 if (i > 0) {
                   $(lyrics[i-1]).removeClass('highlight');
                 }
                 lastTime = timeupdate['currentTime'];
                 el.addClass('highlight');
                 break;
               }
             }
          }
        }
      }
    });
    var playerEl = document.getElementById("player");
    playerEl.insertBefore(track.render(), playerEl.childNodes[0]);
  }
}

var KantasHearWord = {
  words: [],
  correct: false,

  addWord: function(word, times) {
    this.words.push([word, times]);
  },

  showWord: function() {
    var word_and_time = this.words[0];
    this.game_times = word_and_time[1];
    $('.game-word').html(word_and_time[0]);
  },

  renderTrack: function(artist, title) {
    var width = 250;
    var height = 250;
    var times = this.game_times;
    var lastTime = 0;
    var track = window.tomahkAPI.Track(title, artist, {
      width:width,
      height:height,
      disabledResolvers: [ 'spotify' ],
      handlers: {
        ontimeupdate: function(timeupdate) {
          if (timeupdate['currentTime'] > 0) {
//            for (var i = 0; i < times.length; i++) {
            var i = 0;
             var time = times[i][0];
             var nextTime = times[i][1];
             if (timeupdate['currentTime'] >= time && timeupdate['currentTime'] <= nextTime) {
               this.correct = true;
               console.log(this.correct + " time:"+time + " curtime"+ timeupdate['currentTime']);
//               break;
             } else {
               if (this.correct) {
                 console.log('not any more');
               }
               this.correct = false;
             }

//            }
          }
        }
      }
    });
    var playerEl = document.getElementById("player");
    playerEl.insertBefore(track.render(), playerEl.childNodes[0]);
  },

  checkResponse: function(event) {
    var el = $('.game-word');
    if (this.correct) {
      el.addClass('highlight-success');
    } else {
      el.addClass('highlight-error');
    }
  }

};