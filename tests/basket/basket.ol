include "basket.iol"

include "console.iol"

execution{concurrent}

inputPort LocalInputBasketPort {
  Location: "socket://localhost:8080"
  Protocol: sodep
  Interfaces: IBasket
}

cset {
	bid:
    ListItemsRequest.bid
    RemoveItemRequest.bid
    AddItemRequest.bid
    CheckoutRequest.bid
    DiscardRequest.bid
}

main {

  [ register ( register_request ) ( register_response ) {
    //println@Console("register")();
    csets.bid = register_request;
    register_response = true } ]
  {
    provide
    [ addItem ( additem_request ) ( additem_response ) {
    //  println@Console("AddItem")();
      global.baskets.(csets.bid).(additem_request) = true;
      additem_response = true
    } ]
    [ removeItem ( removeitem_request ) ( removeitem_response ) {
      undef (global.baskets.(csets.bid).(additem_removeitem_request));
      removeitem_response = true
    } ]
    [ listItems ( listitems_request ) ( listitems_response ) {
    //  println@Console("list")();
      listitems_response << global.baskets.(csets.bid)
    } ]
    until
    [ checkout ( checkout_request ) ( checkout_response ) {
      listitems_response << global.baskets.(csets.bid)
    } ]
    [ discard ( discard_request ) ( discard_response ) {
      undef(lobal.baskets.(csets.bid));
      discard_response = true
    }]
  }

}
