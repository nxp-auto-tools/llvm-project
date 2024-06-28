;
; Copyright 2024 NXP
;
; RUN: llc -mtriple=riscv32 -mattr=+experimental-zilsd -verify-machineinstrs -O3 < %s \
; RUN:   | FileCheck %s -check-prefix=RV32ZILSD

; // The IR code was obtained from the following C code.
; volatile long long x;
; 
; struct str {
;     int a;
;     int b;
;     int c;
;     int d;
;     int e;
; } s;
; 
; int v[1000]; 
; int *p = v;
; 
; extern int g(struct str *x);
; extern int printf(const char *format, ...);
; 
; void f(int x1, int y1, long long t) {
; 
;     //Check globals and locals long long
;     volatile long long local = t;
;     x = t;
;     printf("%lld %lld\n", x, local);
; 
;     //Check globals and locals pointers and arrays
;     *(p+2) = x1;
;     *(p+3) = y1;
; 
;     *(p+5) = x1;
;     *(p+6) = y1;
; 
;     v[11] = x1;
;     v[12] = y1;
; 
;     v[8] = x1;
;     v[9] = y1;
;     
;     for (int i = 0; i < 1000; i++)
;         printf("%d", v[i]);
; 
; 
;     int v_local[1000]; 
;     int *p_local = v_local;
; 
;     *(p_local+2) = x1;
;     *(p_local+3) = y1;
; 
;     *(p_local+5) = x1;
;     *(p_local+6) = y1;
; 
;     v_local[11] = x1;
;     v_local[12] = y1;
; 
;     v_local[8] = x1;
;     v_local[9] = y1;
;     
;     for (int i = 0; i < 1000; i++) 
;         printf("%d", v_local[i]);
; 
; 
;     //Check globals and locals structs
;     s.a = x1;
;     s.b = y1;
;     s.c = x1;
;     s.d = x1;
;     s.e = y1;
;     
;     printf("%d", g(&s));
; 
;     struct str s_local;
; 
;     s_local.a = x1;
;     s_local.b = y1;
;     s_local.c = x1;
;     s_local.d = x1;
;     s_local.e = y1;
;     
;     printf("%d", g(&s_local));
; 


%struct.str = type { i32, i32, i32, i32, i32 }

@v = dso_local global [1000 x i32] zeroinitializer, align 4
@p = dso_local local_unnamed_addr global ptr @v, align 4
@x = dso_local global i64 0, align 8
@.str = private unnamed_addr constant [11 x i8] c"%lld %lld\0A\00", align 1
@.str.1 = private unnamed_addr constant [3 x i8] c"%d\00", align 1
@s = dso_local global %struct.str zeroinitializer, align 4

; Function Attrs: minsize nounwind optsize uwtable
define dso_local void @f(i32 noundef %x1, i32 noundef %y1, i64 noundef %t) local_unnamed_addr #0 {
entry:
  %local = alloca i64, align 8
  %v_local = alloca [1000 x i32], align 4
  %s_local = alloca %struct.str, align 4
  store volatile i64 %t, ptr %local, align 8, !tbaa !5

; Check global long long
; RV32ZILSD:  sd	a2, 0(a4)

  store volatile i64 %t, ptr @x, align 8, !tbaa !5
  %0 = load volatile i64, ptr @x, align 8, !tbaa !5
  %local.0.local.0.local.0.local.0. = load volatile i64, ptr %local, align 8, !tbaa !5

; Check local long long
; RV32ZILSD:      lui	a5, %hi(x)
; RV32ZILSD-NEXT: sd	a2, %lo(x)(a5)
; RV32ZILSD-NEXT: ld	a2, %lo(x)(a5)
; RV32ZILSD-NEXT: ld	a4, 0(a4)

  %call = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str, i64 noundef %0, i64 noundef %local.0.local.0.local.0.local.0.) #4
  %1 = load ptr, ptr @p, align 4, !tbaa !9
  %add.ptr = getelementptr inbounds i32, ptr %1, i32 2
  store i32 %x1, ptr %add.ptr, align 4, !tbaa !11
  %add.ptr1 = getelementptr inbounds i32, ptr %1, i32 3
  store i32 %y1, ptr %add.ptr1, align 4, !tbaa !11
  %add.ptr2 = getelementptr inbounds i32, ptr %1, i32 5
  store i32 %x1, ptr %add.ptr2, align 4, !tbaa !11
  %add.ptr3 = getelementptr inbounds i32, ptr %1, i32 6
  store i32 %y1, ptr %add.ptr3, align 4, !tbaa !11
  store i32 %x1, ptr getelementptr inbounds ([1000 x i32], ptr @v, i32 0, i32 11), align 4, !tbaa !11
  store i32 %y1, ptr getelementptr inbounds ([1000 x i32], ptr @v, i32 0, i32 12), align 4, !tbaa !11
  store i32 %x1, ptr getelementptr inbounds ([1000 x i32], ptr @v, i32 0, i32 8), align 4, !tbaa !11
  store i32 %y1, ptr getelementptr inbounds ([1000 x i32], ptr @v, i32 0, i32 9), align 4, !tbaa !11
  br label %for.cond

; Check global vector and array (unknown alignment)
; RV32ZILSD:        printf 
; RV32ZILSD-NOT:    ld
; RV32ZILSD-NOT:    sd
; RV32ZILSD:        printf

for.cond:                                         ; preds = %for.body, %entry
  %i.0 = phi i32 [ 0, %entry ], [ %inc, %for.body ]
  %exitcond.not = icmp eq i32 %i.0, 1000
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body

for.cond.cleanup:                                 ; preds = %for.cond
  %add.ptr5 = getelementptr inbounds i32, ptr %v_local, i32 2
  store i32 %x1, ptr %add.ptr5, align 4, !tbaa !11
  %add.ptr6 = getelementptr inbounds i32, ptr %v_local, i32 3
  store i32 %y1, ptr %add.ptr6, align 4, !tbaa !11
  %add.ptr7 = getelementptr inbounds i32, ptr %v_local, i32 5
  store i32 %x1, ptr %add.ptr7, align 4, !tbaa !11
  %add.ptr8 = getelementptr inbounds i32, ptr %v_local, i32 6
  store i32 %y1, ptr %add.ptr8, align 4, !tbaa !11
  %arrayidx9 = getelementptr inbounds [1000 x i32], ptr %v_local, i32 0, i32 11
  store i32 %x1, ptr %arrayidx9, align 4, !tbaa !11
  %arrayidx10 = getelementptr inbounds [1000 x i32], ptr %v_local, i32 0, i32 12
  store i32 %y1, ptr %arrayidx10, align 4, !tbaa !11
  %arrayidx11 = getelementptr inbounds [1000 x i32], ptr %v_local, i32 0, i32 8
  store i32 %x1, ptr %arrayidx11, align 4, !tbaa !11
  %arrayidx12 = getelementptr inbounds [1000 x i32], ptr %v_local, i32 0, i32 9
  store i32 %y1, ptr %arrayidx12, align 4, !tbaa !11
  br label %for.cond14

; Check local vector and array 
; RV32ZILSD:         sd	s2, 48(sp) 
; RV32ZILSD-NEXT:    sw	s2, 60(sp)
; RV32ZILSD-NEXT:    sw	s3, 64(sp)
; RV32ZILSD-NEXT:    sw	s2, 84(sp)
; RV32ZILSD-NEXT:    sw	s3, 88(sp)
; RV32ZILSD-NEXT:    sd	s2, 72(sp)

for.body:                                         ; preds = %for.cond
  %arrayidx = getelementptr inbounds [1000 x i32], ptr @v, i32 0, i32 %i.0
  %2 = load i32, ptr %arrayidx, align 4, !tbaa !11
  %call4 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.1, i32 noundef %2) #4
  %inc = add nuw nsw i32 %i.0, 1
  br label %for.cond, !llvm.loop !13

for.cond14:                                       ; preds = %for.body17, %for.cond.cleanup
  %i13.0 = phi i32 [ 0, %for.cond.cleanup ], [ %inc21, %for.body17 ]
  %exitcond59.not = icmp eq i32 %i13.0, 1000
  br i1 %exitcond59.not, label %for.cond.cleanup16, label %for.body17

for.cond.cleanup16:                               ; preds = %for.cond14
  store i32 %x1, ptr @s, align 4, !tbaa !15
  store i32 %y1, ptr getelementptr inbounds (%struct.str, ptr @s, i32 0, i32 1), align 4, !tbaa !17
  store i32 %x1, ptr getelementptr inbounds (%struct.str, ptr @s, i32 0, i32 2), align 4, !tbaa !18
  store i32 %x1, ptr getelementptr inbounds (%struct.str, ptr @s, i32 0, i32 3), align 4, !tbaa !19
  store i32 %y1, ptr getelementptr inbounds (%struct.str, ptr @s, i32 0, i32 4), align 4, !tbaa !20
  %call23 = tail call i32 @g(ptr noundef nonnull @s) #6
  %call24 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.1, i32 noundef %call23) #4

; Check global struct (unknown alignment)
; RV32ZILSD:        printf 
; RV32ZILSD-NOT:    ld
; RV32ZILSD-NOT:    sd
; RV32ZILSD:        printf 
  
  store i32 %x1, ptr %s_local, align 4, !tbaa !15
  %b = getelementptr inbounds %struct.str, ptr %s_local, i32 0, i32 1
  store i32 %y1, ptr %b, align 4, !tbaa !17
  %c = getelementptr inbounds %struct.str, ptr %s_local, i32 0, i32 2
  store i32 %x1, ptr %c, align 4, !tbaa !18
  %d = getelementptr inbounds %struct.str, ptr %s_local, i32 0, i32 3
  store i32 %x1, ptr %d, align 4, !tbaa !19
  %e = getelementptr inbounds %struct.str, ptr %s_local, i32 0, i32 4
  store i32 %y1, ptr %e, align 4, !tbaa !20
  %call25 = call i32 @g(ptr noundef nonnull %s_local) #6
  %call26 = call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.1, i32 noundef %call25) #4
  ret void

; Check local struct
; RV32ZILSD:         sd	s2, 16(sp) 
; RV32ZILSD:         sd	a0, 24(sp)
; RV32ZILSD-NEXT:    sw	s3, 32(sp)

for.body17:                                       ; preds = %for.cond14
  %arrayidx18 = getelementptr inbounds [1000 x i32], ptr %v_local, i32 0, i32 %i13.0
  %3 = load i32, ptr %arrayidx18, align 4, !tbaa !11
  %call19 = tail call i32 (ptr, ...) @printf(ptr noundef nonnull dereferenceable(1) @.str.1, i32 noundef %3) #4
  %inc21 = add nuw nsw i32 %i13.0, 1
  br label %for.cond14, !llvm.loop !21
}

; Function Attrs: minsize nofree nounwind optsize
declare dso_local noundef i32 @printf(ptr nocapture noundef readonly, ...) local_unnamed_addr #2

; Function Attrs: minsize optsize
declare dso_local i32 @g(ptr noundef) local_unnamed_addr #3

attributes #0 = { minsize nounwind optsize uwtable "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic-rv32" "target-features"="+32bit,+c,+m,+relax,+experimental-zilsd" }
attributes #1 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { minsize nofree nounwind optsize "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic-rv32" "target-features"="+32bit,+c,+m,+relax,+experimental-zilsd" }
attributes #3 = { minsize optsize "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="generic-rv32" "target-features"="+32bit,+c,+m,+relax,+experimental-zilsd" }
attributes #4 = { minsize optsize }
attributes #5 = { nounwind }
attributes #6 = { minsize nounwind optsize }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 1, !"target-abi", !"ilp32"}
!2 = !{i32 7, !"uwtable", i32 2}
!3 = !{i32 8, !"SmallDataLimit", i32 8}
!4 = !{!"clang version 17.0.6"}
!5 = !{!6, !6, i64 0}
!6 = !{!"long long", !7, i64 0}
!7 = !{!"omnipotent char", !8, i64 0}
!8 = !{!"Simple C/C++ TBAA"}
!9 = !{!10, !10, i64 0}
!10 = !{!"any pointer", !7, i64 0}
!11 = !{!12, !12, i64 0}
!12 = !{!"int", !7, i64 0}
!13 = distinct !{!13, !14}
!14 = !{!"llvm.loop.mustprogress"}
!15 = !{!16, !12, i64 0}
!16 = !{!"str", !12, i64 0, !12, i64 4, !12, i64 8, !12, i64 12, !12, i64 16}
!17 = !{!16, !12, i64 4}
!18 = !{!16, !12, i64 8}
!19 = !{!16, !12, i64 12}
!20 = !{!16, !12, i64 16}
!21 = distinct !{!21, !14}