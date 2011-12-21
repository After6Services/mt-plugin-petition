var fCallBack = function callBack(o) {
  var resp = eval('(' + o.responseText + ')');
  var pollquiz = YAHOO.util.Dom.get('pollquiz');
  pollquiz.innerHTML = resp['result'];

  if (resp['cookie']) YAHOO.util.Cookie.set( resp['cookie'], "1" ,{ path: "/" });

}

function postVote(target,formName) {
  YAHOO.util.Connect.setForm(formName);
  YAHOO.util.Connect.asyncRequest('POST',target,{ success:fCallBack});
}

function checkHasVoted(target,formName, poll_id, blog_id) {
	var value = YAHOO.util.Cookie.get("poll-" + poll_id);
	if (value == 1) postVote(target,formName);
}

