// Tests, partD

void __putsi(char *s, int x);
void assert(int cond);
void aeq(int lhs, int rhs) {
    if (lhs != rhs) {
        __putsi("lhs = ", lhs);
        __putsi("rhs = ", rhs);
    }
    assert(lhs == rhs);
}

int param_decay(int x[]) { return x[0]; }

void test01_incomplete_array_type() {
    aeq(4, sizeof(int(*)[10]));
    aeq(4, sizeof(int(*)[][10]));

    aeq(3, ({ int x[2]; x[0]=3; param_decay(x); }));
}

void test02_incomplete_struct() {
    aeq(4, ({ struct foo *bar; sizeof(bar); }));
    aeq(4, ({ struct T *foo; struct T {int x;}; sizeof(struct T); }));
    aeq(1, ({ struct T { struct T *next; int x; } a; struct T b; b.x=1; a.next=&b; a.next->x; }));
    aeq(4, ({ typedef struct T T; struct T { int x; }; sizeof(T); }));
}

int goto_a() { int i=0; goto a; a: i++; b: i++; c: i++; return i; }
int goto_b() { int i=0; goto b; a: i++; b: i++; c: i++; return i; }
int goto_c() { int i=0; goto c; a: i++; b: i++; c: i++; return i; }

int goto_break_nested_loop() {
    int a = 0, b = 0;
    for (; a < 10; a++) {
        for (int j = 0; j < 10; j++, b++) {
            if (a >= 2 && j >= 5) {
                goto end;
            }
        }
    }
end:
    return a * 256 + b;
}

void test03_forward_goto() {
    aeq(3, ({ int i=0; goto a; a: i++; b: i++; c: i++; i; }));
    aeq(2, ({ int i=0; goto e; d: i++; e: i++; f: i++; i; }));
    aeq(1, ({ int i=0; goto i; g: i++; h: i++; i: i++; i; }));

    aeq(3, goto_a());
    aeq(2, goto_b());
    aeq(1, goto_c());

    aeq(  2, goto_break_nested_loop() / 256);  // a
    aeq( 25, goto_break_nested_loop() % 256);  // b
    aeq(256 * 2 + 25, goto_break_nested_loop());
}

void test04_labels_and_typedefs() {
    aeq(1, ({ typedef int foo; goto foo; foo:; 1; }));
}

void test05_break_and_continue() {
    aeq(3, ({ int i=0; for(;i<10;i++) { if (i == 3) break; } i; }));
    aeq(4, ({ int i=0; while (1) { if (i++ == 3) break; } i; }));
    aeq(3, ({ int i=0; for(;i<10;i++) { for (;;) break; if (i == 3) break; } i; }));
    aeq(4, ({ int i=0; while (1) { while(1) break; if (i++ == 3) break; } i; }));

    aeq(10, ({ int i=0; int j=0; for (;i<10;i++) { if (i>5) continue; j++; } i; }));
    aeq(6, ({ int i=0; int j=0; for (;i<10;i++) { if (i>5) continue; j++; } j; }));
    aeq(10, ({ int i=0; int j=0; for(;!i;) { for (;j!=10;j++) continue; break; } j; }));
    aeq(11, ({ int i=0; int j=0; while (i++<10) { if (i>5) continue; j++; } i; }));
    aeq(5, ({ int i=0; int j=0; while (i++<10) { if (i>5) continue; j++; } j; }));
    aeq(11, ({ int i=0; int j=0; while(!i) { while (j++!=10) continue; break; } j; }));
}

void test06_switch() {
    aeq(5, ({ int i=0; switch(0) { case 0:i=5;break; case 1:i=6;break; case 2:i=7;break; } i; }));
    aeq(6, ({ int i=0; switch(1) { case 0:i=5;break; case 1:i=6;break; case 2:i=7;break; } i; }));
    aeq(7, ({ int i=0; switch(2) { case 0:i=5;break; case 1:i=6;break; case 2:i=7;break; } i; }));
    aeq(0, ({ int i=0; switch(3) { case 0:i=5;break; case 1:i=6;break; case 2:i=7;break; } i; }));
    aeq(5, ({ int i=0; switch(0) { case 0:i=5;break; default:i=7; } i; }));
    aeq(7, ({ int i=0; switch(1) { case 0:i=5;break; default:i=7; } i; }));
    aeq(2, ({ int i=0; switch(1) { case 0: 0; case 1: 0; case 2: 0; i=2; } i; }));
    aeq(0, ({ int i=0; switch(3) { case 0: 0; case 1: 0; case 2: 0; i=2; } i; }));
    aeq(3, ({ int i=0; switch(-1) { case -1: i=3; break; } i; }));

    // continue from inside a switch
    {
        int total = 0;
        for (int i = 0; i < 10; i++) {
            switch (i) {
                case 4: break;
                case 5: continue;
                case 6:case 7: break;
            }
            total += i;
        }
        aeq(40, total);
    }
}

void test06_shift() {
    aeq(1024>>5, 1<<5);
    aeq(1, 1<<0);
    aeq(8, 1<<3);
    aeq(10, 5<<1);
    aeq(2, 5>>1);
    aeq(-1, -1>>1);
    aeq(1, ({ int i=1; i<<=0; i; }));
    aeq(8, ({ int i=1; i<<=3; i; }));
    aeq(10, ({ int i=5; i<<=1; i; }));
    aeq(2, ({ int i=5; i>>=1; i; }));
    aeq(-1, -1);
    aeq(-1, ({ int i=-1; i; }));
    aeq(-1, ({ int i=-1; i>>=1; i; }));
}

void test07_cond() {
    aeq(2, 0?1:2);
    aeq(1, 1?1:2);
    aeq(-1, 0?-2:-1);
    aeq(-2, 1?-2:-1);
    aeq(4, sizeof(0?1:2));
    aeq(8, sizeof(0?(long)1:(long)2));
    aeq(-1, 0?(long)-2:-1);
    aeq(-1, 0?-2:(long)-1);
    aeq(-2, 1?(long)-2:-1);
    aeq(-2, 1?-2:(long)-1);
    1 ? -2 : (void)-1;
}

void test08_constexpr() {
    aeq(10, ({ enum { ten=1+2+3+4 }; ten; }));
    aeq(1, ({ int i=0; switch(3) { case 5-2+0*3: i++; } i; }));
    aeq(8, ({ int x[1+1]; sizeof(x); }));
    aeq(6, ({ char x[8-2]; sizeof(x); }));
    aeq(6, ({ char x[2*3]; sizeof(x); }));
    aeq(3, ({ char x[12/4]; sizeof(x); }));
    aeq(2, ({ char x[12%10]; sizeof(x); }));
    aeq(0b100, ({ char x[0b110&0b101]; sizeof(x); }));
    aeq(0b111, ({ char x[0b110|0b101]; sizeof(x); }));
    aeq(0b110, ({ char x[0b111^0b001]; sizeof(x); }));
    aeq(4, ({ char x[1<<2]; sizeof(x); }));
    aeq(2, ({ char x[4>>1]; sizeof(x); }));
    aeq(2, ({ char x[(1==1)+1]; sizeof(x); }));
    aeq(1, ({ char x[(1!=1)+1]; sizeof(x); }));
    aeq(1, ({ char x[(1<1)+1]; sizeof(x); }));
    aeq(2, ({ char x[(1<=1)+1]; sizeof(x); }));
    aeq(2, ({ char x[1?2:3]; sizeof(x); }));
    aeq(3, ({ char x[0?2:3]; sizeof(x); }));
    aeq(3, ({ char x[(1,3)]; sizeof(x); }));
    aeq(2, ({ char x[!0+1]; sizeof(x); }));
    aeq(1, ({ char x[!1+1]; sizeof(x); }));
    aeq(2, ({ char x[~-3]; sizeof(x); }));
    aeq(2, ({ char x[(5||6)+1]; sizeof(x); }));
    aeq(1, ({ char x[(0||0)+1]; sizeof(x); }));
    aeq(2, ({ char x[(1&&1)+1]; sizeof(x); }));
    aeq(1, ({ char x[(1&&0)+1]; sizeof(x); }));
    aeq(3, ({ char x[(int)3]; sizeof(x); }));
    aeq(15, ({ char x[(char)0xffffff0f]; sizeof(x); }));
    aeq(0x10f, ({ char x[(short)0xffff010f]; sizeof(x); }));
    aeq(4, ({ char x[(int)0xfffffffffff+5]; sizeof(x); }));

    // TODO: Consider whether I want to support pointer arithmetic in
    // constant expressions.
    // aeq(8, ({ char x[(int*)0+2]; sizeof(x); }));
    // aeq(12, ({ char x[(int*)16-1]; sizeof(x); }));
    // aeq(3, ({ char x[(int*)16-(int*)4]; sizeof(x); }));
}

void test08_local_var_inits() {
    aeq(1, ({ int x[3]={1,2,3}; x[0]; }));
    aeq(2, ({ int x[3]={1,2,3}; x[1]; }));
    aeq(3, ({ int x[3]={1,2,3}; x[2]; }));
    aeq(3, ({ int x[3]={1,2,3}; x[2]; }));

    aeq(2, ({ int x[2][3]={{1,2,3},{4,5,6}}; x[0][1]; }));
    aeq(4, ({ int x[2][3]={{1,2,3},{4,5,6}}; x[1][0]; }));
    aeq(6, ({ int x[2][3]={{1,2,3},{4,5,6}}; x[1][2]; }));

    aeq(0, ({ int x[3]={}; x[0]; }));
    aeq(0, ({ int x[3]={}; x[1]; }));
    aeq(0, ({ int x[3]={}; x[2]; }));

    aeq(2, ({ int x[2][3]={{1,2}}; x[0][1]; }));
    aeq(0, ({ int x[2][3]={{1,2}}; x[1][0]; }));
    aeq(0, ({ int x[2][3]={{1,2}}; x[1][2]; }));

    aeq('a', ({ char x[4]="abc"; x[0]; }));
    aeq('c', ({ char x[4]="abc"; x[2]; }));
    aeq(0, ({ char x[4]="abc"; x[3]; }));
    aeq('a', ({ char x[2][4]={"abc","def"}; x[0][0]; }));
    aeq(0, ({ char x[2][4]={"abc","def"}; x[0][3]; }));
    aeq('d', ({ char x[2][4]={"abc","def"}; x[1][0]; }));
    aeq('f', ({ char x[2][4]={"abc","def"}; x[1][2]; }));

    aeq(0, ({ int x[]={}; sizeof(x); })); // NOTE: zero-length array is not standard
    aeq(4, ({ int x[]={1}; sizeof(x); }));
    aeq(8, ({ int x[]={1,2}; sizeof(x); }));
    aeq(12, ({ int x[]={1,2,3}; sizeof(x); }));

    aeq(4, ({ int x[]={1,2,3,4}; x[3]; }));
    aeq(16, ({ int x[]={1,2,3,4}; sizeof(x); }));
    aeq(4, ({ char x[]="foo"; sizeof(x); }));

    aeq(4, ({ typedef char T[]; T x="foo"; T y="x"; sizeof(x); }));
    aeq(2, ({ typedef char T[]; T x="foo"; T y="x"; sizeof(y); }));
    aeq(2, ({ typedef char T[]; T x="x"; T y="foo"; sizeof(x); }));
    aeq(4, ({ typedef char T[]; T x="x"; T y="foo"; sizeof(y); }));
    aeq('f', ({ typedef char T[]; T x="x"; T y="foo"; y[0]; }));
}

int goto_count(int n) {
    int i = 0;
    int total = 0;
    {
start:
        i++;
        if (i < n) {
            total += i;
            goto start;
        }
    }
    return total;
}

void test09_backward_goto() {
    aeq(45, goto_count(10));
}

int main() {
    test01_incomplete_array_type();
    test02_incomplete_struct();
    test03_forward_goto();
    test04_labels_and_typedefs();
    test05_break_and_continue();
    test06_switch();
    test06_shift();
    test07_cond();
    test08_local_var_inits();
    test09_backward_goto();
}
