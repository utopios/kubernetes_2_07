func mutatePod(pod *v1.Pod) {
	if pod.Spec.SecurityContext == nil {
		pod.Spec.SecurityContext = &v1.PodSecurityContext{}
	}
	// Set the runAsUser to 1000
	if pod.Spec.SecurityContext.RunAsUser == nil {
		pod.Spec.SecurityContext.RunAsUser = new(int64)
		*pod.Spec.SecurityContext.RunAsUser = 1000
	}
	// Set the runAsGroup to 3000
	if pod.Spec.SecurityContext.RunAsGroup == nil {
		pod.Spec.SecurityContext.RunAsGroup = new(int64)
		*pod.Spec.SecurityContext.RunAsGroup = 3000
	}			
}