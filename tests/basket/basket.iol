type BasketID:string
type AddItemRequest:string { .bid:BasketID }
type RemoveItemRequest:string { .bid:BasketID }
type ListItemsRequest:void { .bid:BasketID }
type CheckoutRequest:void { .bid:BasketID }
type DiscardRequest:void { .bid:BasketID }

interface IBasket {
  RequestResponse:
    register ( BasketID ) ( bool ),
    addItem ( AddItemRequest ) ( bool ),
    removeItem ( RemoveItemRequest ) ( bool ),
    listItems ( ListItemsRequest ) ( undefined ) ,
    checkout ( CheckoutRequest ) ( undefined ),
    discard ( DiscardRequest ) ( bool )
}

outputPort Basket {
  Location: "socket://localhost:8080"
  Protocol: sodep
  Interfaces: IBasket
}
