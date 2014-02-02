var global_time = 0;
var KantasCompleteLyrics = {
  perfectScore: true,
  perfectScoreMessage: '',

  checkResponse: function(i, j) {
    var el = $('#word-'+i+'-'+j);
    if (el.val().toLowerCase().replace(/[-.,()&$#!\[\]\*{}"']/, '') == el.attr('data-value')) {
      var next = $(':input:eq(' + ($(":input").index(el) + 1) + ")");
      el.replaceWith('<span class="success" id="#word-'+i+'-'+j+'">'+el.attr('data-show')+'</span>');
      this.addSuccessScore(el);
      if ($('input').length == 0) {
        var success = $('.alert-success');
        this.addFinalScore(this.localStorageKey);
        if (this.perfectScore) {
          success.html(success.html() + ' ' + this.perfectScoreMessage);
        }
        success.show();
      } else {
        next.focus();
      }
    } else {
      if (el.val() != '') {
        el.addClass('error');
      }
    }
  },

  supportsLocalStorage: function() {
    try {
      return 'localStorage' in window && window['localStorage'] !== null;
    } catch (e) {
      return false;
    }
  },

  addFailureScore: function(i, j) {
    var el = $('#word-'+i+'-'+j);
    if (el.hasClass('error')) {
      this.addScore(this.localStorageKey, -1);
      this.perfectScore = false;
    }
  },

  addScore: function(key, value) {
    if (!this.supportsLocalStorage()) { return false; }

    if (localStorage[key] === undefined) {
      localStorage[key] = 0;
    }
    var score = parseInt(localStorage[key]);
    score = score + value;
    localStorage[key] = score;
    this.updateScoreBoard(score);
  },

  addFinalScore: function(key) {
    if (!this.supportsLocalStorage()) { return false; }
    if (localStorage[key+'-highest'] === undefined) {
      localStorage[key+'-highest'] = 0;
    }
    if (localStorage[key] > localStorage[key+'-highest']) {
      localStorage[key+'-highest'] = localStorage[key];
    }
  },

  addSuccessScore: function(el) {
    this.addScore(this.localStorageKey, 5);
  },

  updateScoreBoard: function(score) {
    if (!this.supportsLocalStorage()) { return false; }
    var el = $('#score');
    el.html(score);
    if (localStorage[this.localStorageKey+'-highest'] !== undefined) {
      var el = $('#highest-score');
      el.html(this.highestScoreMessage+': '+localStorage[this.localStorageKey+'-highest']);
    }
  },

  loadScoreBoard: function(artist, title) {
    if (!this.supportsLocalStorage()) { return false; }
    this.localStorageKey = artist+'-'+title+'-score';
    localStorage[this.localStorageKey] = 0;
    this.updateScoreBoard(localStorage[this.localStorageKey]);
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
  word_index: 0,

  addWord: function(word, times) {
    KantasHearWord.words.push([word, times]);
  },

  showWord: function() {
    var word_and_time = KantasHearWord.words[KantasHearWord.word_index];
    if (word_and_time !== undefined) {
      KantasHearWord.game_word.html(word_and_time[0]);
      KantasHearWord.game_times = word_and_time[1];
    } else {
      KantasHearWord.game_word.html('Game over');
    }
  },

  renderTrack: function(artist, title) {
    var width = 300;
    var height = 300;
    var track = window.tomahkAPI.Track(title, artist, {
      width:width,
      height:height,
      disabledResolvers: [  ],
      handlers: {
        ontimeupdate: function(timeupdate) {
          if (timeupdate['currentTime'] > 0) {
            global_time = timeupdate['currentTime'];
            var time = KantasHearWord.game_times[0];
            var nextTime = KantasHearWord.game_times[1];
//            console.log(global_time+">="+time+" and " + global_time + '<=' + nextTime);
            if (timeupdate['currentTime'] >= time && timeupdate['currentTime'] <= nextTime) {
              KantasHearWord.correct = true;
//              console.log(KantasHearWord.correct + " time:" + time + " curtime" + timeupdate['currentTime']);
            } else {
              if (KantasHearWord.correct) {
                KantasHearWord.pickNextWord();
              }
              KantasHearWord.correct = false;
            }
          }
        }
      }
    });
    var playerEl = document.getElementById("player");
    playerEl.insertBefore(track.render(), playerEl.childNodes[0]);
  },

  checkResponse: function(event) {
    if (KantasHearWord.answered) { return true }
//    console.log("Cur time"+ global_time + "corr:" + KantasHearWord.correct);
    KantasHearWord.answered = true;
    if (KantasHearWord.correct) {
      KantasHearWord.game_word.addClass('highlight-success');
      setTimeout(KantasHearWord.pickNextWord, 1000);
    } else {
      KantasHearWord.game_word.addClass('highlight-error');
      setTimeout(KantasHearWord.clearWord, 1000);
    }
  },

  clearWord: function() {
    KantasHearWord.answered = false;
    KantasHearWord.game_word.removeClass('highlight-error');
    KantasHearWord.game_word.removeClass('highlight-success');
  },

  pickNextWord: function() {
    KantasHearWord.word_index += 1;
    KantasHearWord.clearWord();
    KantasHearWord.showWord();
  }

};