#include <stdio.h>
#include <stdlib.h>

int main(){
    int n;

    scanf("%i", &n);
    printf("%i", Agiota(n));
}

int Agiota(int n){
    if(n==0)
        return 500;
    else
        return (Agiota(n-1)-100)*1.1;
}
