include "basket.iol"

include "string_utils.iol"
include "console.iol"
include "time.iol"

/*embedded {
  Jolie: "basket.ol" in Basket
}*/

define warm_up {
  for ( i = 0, i < 200, i ++) {
    bid = new;
    register@Basket(bid)();
    addItem@Basket("item1" { .bid = bid})();
    listItems@Basket({ .bid = bid})(items);
    addItem@Basket("item2" { .bid = bid})();
    listItems@Basket({ .bid = bid})(items);
    checkout@Basket({ .bid = bid})(items)
  }
}

define run_case {
  for ( i = 0, i <= iterations, i ++) {
    bid = new;
    register@Basket(bid)();
    addItem@Basket("item1" { .bid = bid})();
    addItem@Basket("item2" { .bid = bid})();
    listItems@Basket({ .bid = bid})(items);
    checkout@Basket({ .bid = bid})(items)
  }
}

main {
//  warm_up;
  getCurrentTimeMillis@Time()(beforeStart);
  iterations = int(args[0]);
  run_case;
  getCurrentTimeMillis@Time()(rightAfterStart);
  seconds = (rightAfterStart - beforeStart);
  println@Console(iterations+","+seconds)()
}
